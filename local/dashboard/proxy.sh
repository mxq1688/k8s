#!/bin/bash
# 启动 kubectl proxy，供浏览器访问 Dashboard
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-learn}"
CTX="kind-${CLUSTER_NAME}"

kubectl config use-context "$CTX"
echo "代理已启动。浏览器打开:"
echo "http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
echo "按 Ctrl+C 停止"
exec kubectl proxy
