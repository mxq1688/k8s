#!/bin/bash

cat << EOF >>.bashrc
export http_proxy='http://xzproxy.cnsuning.com:8080/'
export https_proxy='http://xzproxy.cnsuning.com:8080/'
export ftp_proxy='http://xzproxy.cnsuning.com:8080/'
export no_proxy='localhost,127.0.0.1'
EOF


echo 'Acquire::http::Proxy "http://xzproxy.cnsuning.com:8080/";' > /etc/apt/apt.conf

mkdir /etc/systemd/system/docker.service.d
cat << EOF >/etc/systemd/system/docker.service.d/http-proxy.conf
[Service]
    Environment=HTTP_PROXY=http://xzproxy.cnsuning.com:8080/
    Environment=HTTPS_PROXY=http://xzproxy.cnsuning.com:8080/
    Environment=NO_PROXY=http://xzproxy.cnsuning.com:8080/
EOF
#刷新配置
systemctl daemon-reload
#重启服务
systemctl restart docker