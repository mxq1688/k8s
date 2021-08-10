#!/bin/bash

# 关闭防火墙
ufw disable
# 关闭iptables
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -F

#docker安装
apt-get update
# 安装GPG证书
curl -fsSL http://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo apt-key add -
# 写入软件源信息
add-apt-repository "deb [arch=amd64] http://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
# 更新软件库
apt-get -y update
# 安装程序
apt-get -y install docker-ce=5:19.03.15~3-0~ubuntu-bionic
# 固定版本
apt-mark hold docker-ce
mkdir -p /etc/docker
tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": ["https://g6ogy192.mirror.aliyuncs.com"],
  "exec-opts": ["native.cgroupdriver=systemd"] 
}
EOF
systemctl daemon-reload
systemctl restart docker
journalctl -u docker.server
usermod -aG docker root

#Kubernetes组件安装
# 下载 gpg 密钥
curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add -
# 添加 k8s 镜像源
cat <<EOF > /etc/apt/sources.list.d/kubernetes.list
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF
# 更新软件库
apt-get update
# 安装程序
apt-get install -y kubelet=1.18.0-00 kubeadm=1.18.0-00 kubectl=1.18.0-00
# 固定版本
apt-mark hold kubelet kubeadm kubectl
# 配置自启动
sudo systemctl enable kubelet && sudo systemctl start kubelet

exit 0

#命令查看当前集群所需要的镜像
kubeadm config images list

docker pull registry.aliyuncs.com/google_containers/kube-apiserver:v1.18.20
docker pull registry.aliyuncs.com/google_containers/kube-controller-manager:v1.18.20
docker pull registry.aliyuncs.com/google_containers/kube-scheduler:v1.18.20
docker pull registry.aliyuncs.com/google_containers/kube-proxy:v1.18.20
docker pull registry.aliyuncs.com/google_containers/pause:3.2
docker pull registry.aliyuncs.com/google_containers/etcd:3.4.3-0
docker pull registry.aliyuncs.com/google_containers/coredns:1.6.7

docker tag registry.aliyuncs.com/google_containers/kube-apiserver:v1.18.20 k8s.gcr.io/kube-apiserver:v1.18.20
docker tag registry.aliyuncs.com/google_containers/kube-controller-manager:v1.18.20 k8s.gcr.io/kube-controller-manager:v1.18.20
docker tag registry.aliyuncs.com/google_containers/kube-scheduler:v1.18.20 k8s.gcr.io/kube-scheduler:v1.18.20
docker tag registry.aliyuncs.com/google_containers/kube-proxy:v1.18.20 k8s.gcr.io/kube-proxy:v1.18.20
docker tag registry.aliyuncs.com/google_containers/pause:3.2 k8s.gcr.io/pause:3.2
docker tag registry.aliyuncs.com/google_containers/etcd:3.4.3-0 k8s.gcr.io/etcd:3.4.3-0
docker tag registry.aliyuncs.com/google_containers/coredns:1.6.7 k8s.gcr.io/coredns:1.6.7

docker rmi k8s.gcr.io/kube-apiserver:v1.18.20
docker rmi k8s.gcr.io/kube-controller-manager:v1.18.20
docker rmi k8s.gcr.io/kube-scheduler:v1.18.20
docker rmi k8s.gcr.io/kube-proxy:v1.18.20
docker rmi k8s.gcr.io/pause:3.2
docker rmi k8s.gcr.io/etcd:3.4.3-0
docker rmi k8s.gcr.io/coredns:1.6.7


kubeadm init \
--apiserver-advertise-address=192.168.99.22 \
--image-repository registry.aliyuncs.com/google_containers \
--service-cidr=10.96.0.0/12 \
--pod-network-cidr=10.244.0.0/16 \
--token-ttl=0

kubeadm init --service-cidr=10.96.0.0/12 --pod-network-cidr=10.244.0.0/16  --ignore-preflight-errors=Swap

#配置集群网络 https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
kubectl apply -f kube-flannel.yml

# 让Linux普通用户能操作集群
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

#初始化集群工作节点
kubeadm join

# 查询
kubectl get pods --all-namespaces