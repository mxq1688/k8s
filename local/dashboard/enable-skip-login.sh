#!/bin/bash
# 开启 Dashboard「跳过登录」（本地 kind 用，勿用于生产）
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-learn}"
CTX="kind-${CLUSTER_NAME}"
ROOT="$(cd "$(dirname "$0")" && pwd)"

kubectl config use-context "$CTX"

kubectl apply -f "$ROOT/dashboard-admin-sa.yaml"

kubectl patch deployment kubernetes-dashboard \
  -n kubernetes-dashboard \
  --type='json' \
  -p='[
    {"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--enable-skip-login"},
    {"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--enable-insecure-login"}
  ]'

kubectl rollout status deployment/kubernetes-dashboard -n kubernetes-dashboard --timeout=120s

echo ""
echo "已开启 Skip 登录。请先运行 ./proxy.sh，浏览器打开 Dashboard 后点「跳过」即可，无需 Token。"
