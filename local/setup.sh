#!/bin/bash
# 本地 kind 环境：创建集群并部署 local/nginx
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
KIND_BIN="${KIND_BIN:-kind}"
CLUSTER_NAME="${CLUSTER_NAME:-learn}"

if ! command -v docker >/dev/null; then
  echo "请先安装并启动 Docker Desktop"
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "Docker 未运行，正在尝试启动 Docker Desktop..."
  open -a Docker
  for _ in $(seq 1 40); do
    docker info >/dev/null 2>&1 && break
    sleep 3
  done
fi

if ! command -v "$KIND_BIN" >/dev/null; then
  echo "未找到 kind。可执行: brew install kind"
  exit 1
fi

if ! "$KIND_BIN" get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  echo "创建 kind 集群 $CLUSTER_NAME ..."
  "$KIND_BIN" create cluster --name "$CLUSTER_NAME" --config "$ROOT/kind-config.yaml"
else
  echo "集群 $CLUSTER_NAME 已存在，跳过创建"
fi

kubectl config use-context "kind-$CLUSTER_NAME"

# 国内网络：先把镜像导入 kind 节点，避免 Pod ImagePullBackOff
if ! docker image inspect nginx:alpine >/dev/null 2>&1; then
  docker pull nginx:alpine
fi
"$KIND_BIN" load docker-image nginx:alpine --name "$CLUSTER_NAME"

kubectl apply -k "$ROOT"
kubectl rollout status deployment/nginx --timeout=120s

echo ""
echo "本地集群就绪。访问: http://localhost:8081"
echo "  kubectl get pods,svc -n default"
echo "  $KIND_BIN delete cluster --name $CLUSTER_NAME"
