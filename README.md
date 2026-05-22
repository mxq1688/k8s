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
| `local/` | Mac 上 kind 集群 + 2 副本 + NodePort（浏览器 :8081） |
| `prod/` | 真集群 + 3 副本 + 探针/资源限制 + ClusterIP |

合并方式：`base` + `local` 或 `prod` 里的 `kustomization.yaml` → `kubectl apply -k`

## 本地

```bash
# 需要：Docker Desktop、kind、kubectl
cd local && ./setup.sh
```

访问 http://localhost:8081

### setup.sh 在干什么

| 步骤 | 命令 | 作用 |
|------|------|------|
| 1 | `kind create cluster ... kind-config.yaml` | 在 Docker 里建集群；8081 映射到 30080 |
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

改配置后执行 `apply -k local/` 即可，**不必**再跑 `setup.sh`（除非集群删了或端口映射丢了）。

### Kubernetes Dashboard（网页管理）

需先有 `kind-learn` 集群（跑过 `setup.sh`）。

```bash
cd local/dashboard && ./install.sh    # 安装并生成 dashboard-admin.kubeconfig
# 另开终端:
./proxy.sh
```

浏览器打开 Dashboard → 登录选 **Kubeconfig** → 上传：

`local/dashboard/dashboard-admin.kubeconfig`

（安装脚本会自动生成，含集群地址和 Token，已加入 `.gitignore` 勿提交。）

**其他登录方式：**

| 方式 | 命令 | 页面上 |
|------|------|--------|
| Kubeconfig（默认） | `./install.sh` | 上传 `dashboard-admin.kubeconfig` |
| 跳过 | `./enable-skip-login.sh` | 点 **跳过** |
| Token | `LOGIN_MODE=token ./install.sh` | 粘贴终端 Token |

Token 过期后重新生成：`cd local/dashboard && ./gen-kubeconfig.sh`

**没有用户名+密码**：新版 K8s 不支持该方式。**勿用于生产**。

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
| `kind-config.yaml` | 仅 `kind create` 时用，配本机 8081→30080 端口 |
| `kustomization.yaml` | 引用 base，副本改 2，打 NodePort 补丁 |
| `service-nodeport.yaml` | 把 Service 改成 NodePort 30080 |
| `dashboard/install.sh` | 安装 Dashboard + 生成 `dashboard-admin.kubeconfig` |
| `dashboard/gen-kubeconfig.sh` | 重新生成 Kubeconfig |
| `dashboard/proxy.sh` | 启动 kubectl proxy 供浏览器访问 |

## 常见问题

**镜像拉不下来**：`docker pull nginx:alpine && kind load docker-image nginx:alpine --name learn`

**网页打不开**：`kubectl get pods,svc`；若 8081 被占用可改 `kind-config.yaml` 的 `hostPort`，删集群后重建

**connect: connection refused**：集群 API 连不上，多为 Docker 重启后端口映射坏了 → `kind delete cluster --name learn && ./local/setup.sh`
