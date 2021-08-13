#!/bin/bash

# 关闭防火墙
ufw disable
# 关闭iptables
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -F

sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release 
# 安装GPG证书
curl -fsSL http://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo apt-key add -
#官方 curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
# 写入软件源信息
add-apt-repository "deb [arch=amd64] http://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
#官方 echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
# 更新软件库
# 更新软件库
apt-get -y update
#查看版本
apt-cache madison docker-ce
# 安装程序
# sudo apt-get install docker-ce=<VERSION_STRING> docker-ce-cli=<VERSION_STRING> containerd.io
apt-get -y install docker-ce=5:19.03.15~3-0~ubuntu-bionic docker-ce-cli=5:19.03.15~3-0~ubuntu-bionic
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

#卸载docker
apt-get -y  remove docker docker-engine docker.io containerd runc
apt-get -y autoremove docker docker-ce docker-engine  docker.io  containerd runc
dpkg -l | grep docker
dpkg -l |grep ^rc|awk '{print $2}' |sudo xargs dpkg -P # 删除无用的相关的配置文件
apt-get -y autoremove docker-ce-*
sudo rm -rf /etc/systemd/system/docker.service.d
sudo rm -rf /var/lib/docker

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

docker pull registry.aliyuncs.com/google_containers/kube-apiserver:v1.18.0
docker pull registry.aliyuncs.com/google_containers/kube-controller-manager:v1.18.0
docker pull registry.aliyuncs.com/google_containers/kube-scheduler:v1.18.0
docker pull registry.aliyuncs.com/google_containers/kube-proxy:v1.18.0
docker pull registry.aliyuncs.com/google_containers/pause:3.2
docker pull registry.aliyuncs.com/google_containers/etcd:3.4.3-0
docker pull registry.aliyuncs.com/google_containers/coredns:1.6.7
docker pull registry.aliyuncs.com/google_containers/coreos/flannel:v0.14.0

docker tag registry.aliyuncs.com/google_containers/kube-apiserver:v1.18.0 k8s.gcr.io/kube-apiserver:v1.18.0
docker tag registry.aliyuncs.com/google_containers/kube-controller-manager:v1.18.0 k8s.gcr.io/kube-controller-manager:v1.18.0
docker tag registry.aliyuncs.com/google_containers/kube-scheduler:v1.18.0 k8s.gcr.io/kube-scheduler:v1.18.0
docker tag registry.aliyuncs.com/google_containers/kube-proxy:v1.18.0 k8s.gcr.io/kube-proxy:v1.18.0
docker tag registry.aliyuncs.com/google_containers/pause:3.2 k8s.gcr.io/pause:3.2
docker tag registry.aliyuncs.com/google_containers/etcd:3.4.3-0 k8s.gcr.io/etcd:3.4.3-0
docker tag registry.aliyuncs.com/google_containers/coredns:1.6.7 k8s.gcr.io/coredns:1.6.7
docker tag registry.aliyuncs.com/google_containers/coreos/flannel:v0.14.0 k8s.gcr.io/coreos/flannel:v0.14.0

docker rmi registry.aliyuncs.com/google_containers/kube-apiserver:v1.18.0
docker rmi registry.aliyuncs.com/google_containers/kube-controller-manager:v1.18.0
docker rmi registry.aliyuncs.com/google_containers/kube-scheduler:v1.18.0
docker rmi registry.aliyuncs.com/google_containers/kube-proxy:v1.18.0
docker rmi registry.aliyuncs.com/google_containers/pause:3.2
docker rmi registry.aliyuncs.com/google_containers/etcd:3.4.3-0
docker rmi registry.aliyuncs.com/google_containers/coreos/flannel:v0.14.0


#重置配置
kubeadm reset -f
rm -rf $HOME/.kube

kubeadm init \
--service-cidr=10.96.0.0/12 \
--kubernetes-version=v1.18.0 \
--pod-network-cidr=10.244.0.0/16 \
--token-ttl=0

kubeadm init --service-cidr=10.96.0.0/12 --pod-network-cidr=10.244.0.0/16  --ignore-preflight-errors=Swap

# 让Linux普通用户能操作集群
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

#配置集群网络 https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml 保存到本地kube-flannel.yml
kubectl apply -f kube-flannel.yml

#初始化集群工作节点
kubeadm join

# 查询pods
kubectl get pods --all-namespaces
kubectl get pods --all-namespaces -o wide
kubectl describe pod 名称 -n namespace
# 查看service
kubectl get service --all-namespaces -o wide
kubectl get service -n kubernetes-dashboard  -o wide
#查询节点
kubectl get nodes

#dashboard
  https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0/aio/deploy/recommended.yaml

  kubectl create -f recommended.yaml 
  kubectl get pod,svc -n kubernetes-dashboard

  spec:
  type: NodePort # 新增
  ports:
    - port: 443
      targetPort: 8443
      nodePort: 30443 # 新增

  #创建管理员用户yaml vim adminuser.yaml
  kubectl create -f adminuser.yaml

  #查看token
  kubectl -n kubernetes-dashboard describe secret $(kubectl -n kubernetes-dashboard get secret | grep admin-user | awk '{print $1}')
  #如果Token忘记了，可以用下面命令直接找出Token
  kubectl -n kube-system describe $(kubectl -n kube-system get secret -n kube-system -o name | grep namespace) | grep token
  火狐访问

#删除dashboard
  // 查询pod 
  kubectl get pods --all-namespaces | grep "dashboard"
  // 删除pod
  kubectl delete deployment kubernetes-dashboard  --namespace=kubernetes-dashboard
  kubectl delete deployment dashboard-metrics-scraper --namespace=kubernetes-dashboard

  // 查询service
  kubectl get service -A
  // 删除service
  kubectl delete service kubernetes-dashboard  --namespace=kubernetes-dashboard
  kubectl delete service dashboard-metrics-scraper  --namespace=kubernetes-dashboard
  // 删除账户和密钥
  kubectl delete sa kubernetes-dashboard --namespace=kubernetes-dashboard
  kubectl delete secret kubernetes-dashboard-certs --namespace=kubernetes-dashboard
  kubectl delete secret kubernetes-dashboard-key-holder --namespace=kubernetes-dashboard



