#!/bin/bash
# 生产集群部署（需已配置 kubectl 上下文，如 ACK/EKS/kubeadm）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
NAMESPACE="${NAMESPACE:-default}"

ctx="$(kubectl config current-context 2>/dev/null || true)"
if [[ -z "$ctx" ]]; then
  echo "未配置 kubectl 上下文，请先: kubectl config use-context <生产集群>"
  exit 1
fi

if [[ "$ctx" == kind-* ]]; then
  echo "当前上下文是 kind 本地集群 ($ctx)，请切换到生产集群后再执行。"
  exit 1
fi

echo "部署到: context=$ctx namespace=$NAMESPACE"
kubectl apply -n "$NAMESPACE" -k "$ROOT"
kubectl rollout status -n "$NAMESPACE" deployment/nginx --timeout=180s
kubectl get -n "$NAMESPACE" pods,svc -l app=nginx
