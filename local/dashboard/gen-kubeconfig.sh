#!/bin/bash
# 生成供 Dashboard「Kubeconfig」登录使用的配置文件
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-learn}"
CTX="kind-${CLUSTER_NAME}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$ROOT/dashboard-admin.kubeconfig}"

if ! kubectl config get-contexts -o name 2>/dev/null | grep -qx "$CTX"; then
  echo "未找到上下文 $CTX，请先: cd local && ./setup.sh"
  exit 1
fi

if ! kubectl get sa admin-user -n kubernetes-dashboard >/dev/null 2>&1; then
  echo "未找到 admin-user，请先: ./install.sh"
  exit 1
fi

kubectl config use-context "$CTX"

SERVER="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
CA="$(kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')"
TOKEN="$(kubectl create token admin-user -n kubernetes-dashboard --duration=8760h)"

cat > "$OUT" <<EOF
# 本地 kind Dashboard 登录用（勿提交 git、勿分享）
apiVersion: v1
kind: Config
clusters:
  - name: ${CLUSTER_NAME}
    cluster:
      server: ${SERVER}
      certificate-authority-data: ${CA}
users:
  - name: admin-user
    user:
      token: ${TOKEN}
contexts:
  - name: admin-user@${CLUSTER_NAME}
    context:
      cluster: ${CLUSTER_NAME}
      user: admin-user
current-context: admin-user@${CLUSTER_NAME}
EOF

chmod 600 "$OUT"
echo "已生成 Kubeconfig: $OUT"
echo "Dashboard 登录: 选「Kubeconfig」→ 选择该文件上传"
