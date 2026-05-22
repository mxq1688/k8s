#!/bin/bash
# 在 kind-learn 集群安装 Kubernetes Dashboard（仅本地学习）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-learn}"
CTX="kind-${CLUSTER_NAME}"
DASHBOARD_MANIFEST="https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml"
KUBECONFIG_FILE="$ROOT/dashboard-admin.kubeconfig"
LOGIN_MODE="${LOGIN_MODE:-kubeconfig}"

if ! kubectl config get-contexts -o name 2>/dev/null | grep -qx "$CTX"; then
  echo "未找到上下文 $CTX，请先执行: cd local && ./setup.sh"
  exit 1
fi

kubectl config use-context "$CTX"

echo "安装 Dashboard ..."
kubectl apply -f "$DASHBOARD_MANIFEST"
kubectl apply -f "$ROOT/admin-user.yaml"

echo "等待 Dashboard Pod 就绪 ..."
kubectl wait --namespace kubernetes-dashboard \
  --for=condition=ready pod \
  --selector=k8s-app=kubernetes-dashboard \
  --timeout=180s

echo "生成 Kubeconfig ..."
"$ROOT/gen-kubeconfig.sh" "$KUBECONFIG_FILE"

echo ""
echo "======== Dashboard 已安装 ========"
echo "1. 另开终端: cd local/dashboard && ./proxy.sh"
echo "2. 浏览器:"
echo "   http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
echo ""

case "$LOGIN_MODE" in
  skip)
    "$ROOT/enable-skip-login.sh"
    echo "登录: 点「跳过」"
    ;;
  kubeconfig)
    echo "3. 登录页选「Kubeconfig」，上传文件:"
    echo "   $KUBECONFIG_FILE"
    ;;
  token)
    TOKEN="$(kubectl create token admin-user -n kubernetes-dashboard --duration=8760h)"
    echo "3. 登录页选 Token，粘贴:"
    echo ""
    echo "$TOKEN"
    echo ""
    echo "或选 Kubeconfig，上传: $KUBECONFIG_FILE"
    ;;
  *)
    echo "3. 登录页选「Kubeconfig」，上传: $KUBECONFIG_FILE"
    ;;
esac

echo ""
echo "重新生成 Kubeconfig: ./gen-kubeconfig.sh"
echo "改用 Skip 登录:       ./enable-skip-login.sh"
echo "改用 Token:           LOGIN_MODE=token ./install.sh  或 ./gen-kubeconfig.sh 后自行 create token"
