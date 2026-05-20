# k8s 学习仓库

nginx 示例，用 Kustomize 管理，按环境分目录。

## 目录

```text
base/nginx/     公用模板（Deployment + Service）
local/          本地 kind：建集群脚本 + 本地配置
prod/           生产集群：部署脚本 + 生产配置
```

| 目录 | 干什么 |
|------|--------|
| `base/` | 两边都一样的部分，改一处两边生效 |
| `local/` | Mac 上 kind 集群 + 2 副本 + NodePort（浏览器 :8080） |
| `prod/` | 真集群 + 3 副本 + 探针/资源限制 + ClusterIP |

合并方式：`base` + `local` 或 `prod` 里的 `kustomization.yaml` → `kubectl apply -k`

## 本地

```bash
# 需要：Docker Desktop、kind、kubectl
cd local && ./setup.sh
```

访问 http://localhost:8080

### setup.sh 在干什么

| 步骤 | 命令 | 作用 |
|------|------|------|
| 1 | `kind create cluster ... kind-config.yaml` | 在 Docker 里建集群；8080 映射到 30080 |
| 2 | `kubectl config use-context kind-learn` | 后面的 kubectl 都连这台集群 |
| 3 | `kind load docker-image nginx:alpine` | 镜像导入节点，避免拉取失败 |
| 4 | `kubectl apply -k local/` | 合并 base+local 配置并部署 nginx |
| 5 | `kubectl rollout status deployment/nginx` | 等待 Pod 全部就绪 |

`kubectl`、`kind` 需事先安装（如 `brew install kubectl kind`），脚本不会安装它们。

`apply -k local/` 会自动读 `local/kustomization.yaml`，不必手写文件名。

### 日常操作

前提：`kubectl config current-context` 为 `kind-learn`（`setup.sh` 已切换过可跳过）。

| 场景 | 命令 |
|------|------|
| 改了 YAML，重新部署 | `kubectl apply -k local/` |
| 看状态 | `kubectl get pods,svc` |
| 预览合并后的 YAML | `kubectl kustomize local/` |
| 删掉整个本地集群 | `kind delete cluster --name learn` |

改配置后执行 `apply -k local/` 即可，**不必**再跑 `setup.sh`（除非集群删了或 8080 端口映射丢了）。

## 生产

```bash
kubectl config use-context <生产集群>
cd prod && ./deploy.sh
```

不要在 `kind-*` 上下文上跑 `deploy.sh`。

## 环境差异

| | local | prod |
|---|-------|------|
| 集群 | kind | ACK / kubeadm 等 |
| 副本 | 2 | 3 |
| Service | NodePort | ClusterIP |
| 镜像 | nginx:alpine | nginx:1.27-alpine |

## 改配置

- 公用 → `base/nginx/`
- 只改本地 → `local/kustomization.yaml`、`service-nodeport.yaml`
- 只改生产 → `prod/kustomization.yaml`、`deployment-patch.yaml`

预览合并结果：`kubectl kustomize local/`

### local/ 里各文件

| 文件 | 作用 |
|------|------|
| `setup.sh` | 建集群 + 部署（见上表） |
| `kind-config.yaml` | 仅 `kind create` 时用，配本机 8080 端口 |
| `kustomization.yaml` | 引用 base，副本改 2，打 NodePort 补丁 |
| `service-nodeport.yaml` | 把 Service 改成 NodePort 30080 |

## 常见问题

**镜像拉不下来**：`docker pull nginx:alpine && kind load docker-image nginx:alpine --name learn`

**8080 打不开**：`kubectl get pods,svc`，必要时重新 `./local/setup.sh`
