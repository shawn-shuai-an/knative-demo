# Dapr Kubernetes 安装指南

## 先决条件

```yaml
环境要求:
- Kubernetes 集群 (版本 1.20+)
- kubectl 已配置并能访问集群
- 集群中有足够的资源 (推荐至少 2GB 内存, 2 CPU cores)
- 网络策略允许 Pod 间通信
```

## 安装方式概览

```yaml
安装选项:
1. Dapr CLI (推荐) - 最简单，自动处理所有配置
2. Helm Charts - 适合生产环境，可自定义配置
3. Kubernetes YAML - 手动控制，适合高级用户
```

## 方式一：使用 Dapr CLI 安装 (推荐)

### 1. 安装 Dapr CLI

#### macOS (使用 Homebrew)
```bash
# 安装 Dapr CLI
brew install dapr/tap/dapr-cli

# 验证安装
dapr version
```

#### Linux/WSL
```bash
# 下载并安装 Dapr CLI
wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash

# 或者手动下载
curl -fsSL https://raw.githubusercontent.com/dapr/cli/master/install/install.sh | /bin/bash

# 验证安装
dapr version
```

#### Windows (PowerShell)
```powershell
# 使用 PowerShell 安装
powershell -Command "iwr -useb https://raw.githubusercontent.com/dapr/cli/master/install/install.ps1 | iex"

# 验证安装
dapr version
```

### 2. 初始化 Dapr 到 Kubernetes

```bash
# 检查集群连接
kubectl cluster-info

# 初始化 Dapr 到 Kubernetes 集群
dapr init -k

# 这个命令会：
# 1. 创建 dapr-system namespace
# 2. 安装 Dapr control plane 组件
# 3. 配置必要的 RBAC
# 4. 安装默认配置
```

### 3. 验证安装

```bash
# 检查 Dapr 组件状态
dapr status -k

# 预期输出类似：
#   NAME                   NAMESPACE    HEALTHY  STATUS   REPLICAS  VERSION  AGE  CREATED
#   dapr-dashboard         dapr-system  True     Running  1         1.12.0   15s  2023-XX-XX 10:00.00
#   dapr-sidecar-injector  dapr-system  True     Running  1         1.12.0   15s  2023-XX-XX 10:00.00
#   dapr-sentry            dapr-system  True     Running  1         1.12.0   15s  2023-XX-XX 10:00.00
#   dapr-operator          dapr-system  True     Running  1         1.12.0   15s  2023-XX-XX 10:00.00
#   dapr-placement         dapr-system  True     Running  1         1.12.0   15s  2023-XX-XX 10:00.00

# 检查 Kubernetes 中的 Pods
kubectl get pods -n dapr-system

# 预期看到所有 Pod 都是 Running 状态
```

## 方式二：使用 Helm 安装

### 1. 安装 Helm (如果还没有)

```bash
# macOS
brew install helm

# Linux
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### 2. 添加 Dapr Helm Repository

```bash
# 添加 Dapr Helm repo
helm repo add dapr https://dapr.github.io/helm-charts/

# 更新 repo
helm repo update

# 查看可用版本
helm search repo dapr --devel --versions
```

### 3. 安装 Dapr

```bash
# 创建 namespace
kubectl create namespace dapr-system

# 安装 Dapr (基础配置)
helm upgrade --install dapr dapr/dapr \
  --version=1.12.0 \
  --namespace dapr-system \
  --create-namespace \
  --wait

# 或者使用自定义配置
helm upgrade --install dapr dapr/dapr \
  --version=1.12.0 \
  --namespace dapr-system \
  --create-namespace \
  --set global.ha.enabled=true \
  --set dapr_placement.cluster.forceInMemoryLog=false \
  --wait
```

## 详细组件说明

### Dapr Control Plane 组件

```yaml
dapr-operator:
  作用: 管理 Dapr 组件和配置
  端口: 8080 (metrics), 9443 (webhook)
  
dapr-sidecar-injector:
  作用: 自动注入 sidecar 容器到应用 Pod
  端口: 4000 (健康检查), 9443 (webhook)
  
dapr-placement:
  作用: 管理 Actor 的分布式状态
  端口: 50005 (gRPC), 8080 (metrics)
  
dapr-sentry:
  作用: 证书颁发机构，管理 mTLS
  端口: 50001 (gRPC), 8080 (metrics)
  
dapr-dashboard (可选):
  作用: Web UI 管理界面
  端口: 8080 (HTTP)
```

## 配置访问 Dapr Dashboard

### 1. 检查 Dashboard 是否安装

```bash
# 检查 dashboard pod
kubectl get pods -n dapr-system -l app=dapr-dashboard

# 如果没有安装，手动安装
kubectl apply -f https://raw.githubusercontent.com/dapr/dapr/release-1.12/deploy/kubernetes/dashboard/dapr-dashboard.yaml
```

### 2. 访问 Dashboard

```bash
# 方式1: Port forward (开发环境)
kubectl port-forward svc/dapr-dashboard -n dapr-system 8080:8080

# 然后在浏览器访问: http://localhost:8080

# 方式2: 创建 NodePort Service (测试环境)
kubectl patch svc dapr-dashboard -n dapr-system -p '{"spec":{"type":"NodePort"}}'
kubectl get svc dapr-dashboard -n dapr-system
```

## 创建示例应用验证

### 1. 创建测试应用

```yaml
# test-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-dapr-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
      annotations:
        dapr.io/enabled: "true"
        dapr.io/app-id: "test-app"
        dapr.io/app-port: "8080"
    spec:
      containers:
      - name: test-app
        image: nginx:alpine
        ports:
        - containerPort: 8080
        command: ["/bin/sh"]
        args: ["-c", "while true; do echo 'Test app running'; sleep 30; done"]
---
apiVersion: v1
kind: Service
metadata:
  name: test-app-service
  namespace: default
spec:
  selector:
    app: test-app
  ports:
  - port: 8080
    targetPort: 8080
```

### 2. 部署并验证

```bash
# 部署测试应用
kubectl apply -f test-app.yaml

# 检查 Pod，应该看到两个容器
kubectl get pods -l app=test-app

# 查看 Pod 详情，确认有 sidecar
kubectl describe pod -l app=test-app

# 检查容器
kubectl get pod -l app=test-app -o jsonpath='{.items[0].spec.containers[*].name}'
# 应该输出: test-app daprd
```

## 故障排查

### 常见问题

#### 1. Sidecar 注入失败

```bash
# 检查 sidecar injector 状态
kubectl get pods -n dapr-system -l app=dapr-sidecar-injector

# 检查 webhook 配置
kubectl get mutatingwebhookconfiguration dapr-sidecar-injector

# 检查应用 Pod 事件
kubectl describe pod <your-pod-name>
```

#### 2. 组件启动失败

```bash
# 检查所有 dapr 组件日志
kubectl logs -n dapr-system -l app.kubernetes.io/name=dapr

# 检查特定组件
kubectl logs -n dapr-system -l app=dapr-operator
kubectl logs -n dapr-system -l app=dapr-sidecar-injector
```

#### 3. 网络连接问题

```bash
# 检查 Dapr 组件间的网络连接
kubectl exec -n dapr-system deployment/dapr-operator -- nslookup dapr-sentry.dapr-system.svc.cluster.local

# 检查 sidecar 是否能连接到控制平面
kubectl exec <your-pod-name> -c daprd -- curl -f http://dapr-operator.dapr-system.svc.cluster.local:8080/healthz
```

## 升级 Dapr

### 使用 CLI 升级

```bash
# 查看当前版本
dapr status -k

# 升级到最新版本
dapr upgrade -k

# 升级到特定版本
dapr upgrade -k --runtime-version 1.12.0
```

### 使用 Helm 升级

```bash
# 更新 repo
helm repo update

# 查看可用版本
helm search repo dapr/dapr --versions

# 升级
helm upgrade dapr dapr/dapr --version=1.12.0 --namespace dapr-system
```

## 卸载 Dapr

### 使用 CLI 卸载

```bash
# 卸载 Dapr
dapr uninstall -k

# 确认卸载
kubectl get pods -n dapr-system
```

### 使用 Helm 卸载

```bash
# 卸载 Helm release
helm uninstall dapr --namespace dapr-system

# 删除 namespace
kubectl delete namespace dapr-system
```

## 下一步

安装完成后，您可以：

1. **部署第一个 Dapr 应用** - 修改现有应用添加 Dapr 注解
2. **配置 Pub/Sub 组件** - 创建 Redis 或 Kafka 组件
3. **探索 Dapr Dashboard** - 查看组件和应用状态
4. **集成现有的 Knative 应用** - 对比两种架构 