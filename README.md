# Knative Demo Project

基于 Knative Eventing 的事件驱动架构演示项目，展示生产者-消费者模式的事件处理。

## 项目结构

```
knative_demo/
├── producer/                    # 🚫 历史代码 (已弃用)
├── consumer/                    # 🚫 历史代码 (已弃用)
├── infrastructure/              # ✅ Knative 基础设施配置
│   ├── knative/                # Knative 资源定义
│   ├── kubernetes/             # ConfigMap 代码注入
│   └── scripts/                # 部署脚本
├── scripts/                    # ✅ 全局脚本
└── README.md                   # 项目说明
```

> **📝 架构说明**: 项目已升级为**零镜像构建**架构，使用通用 Python 镜像 + ConfigMap 注入代码的方式部署。

## 架构说明

此项目演示了 Knative Eventing 的核心概念：

- **Producer**: 使用通用 Python 镜像 + ConfigMap，**定时自动**产生 CloudEvents 格式的事件
- **Consumer**: 使用通用 Python 镜像 + ConfigMap，智能处理不同类型的事件 
- **Broker**: 事件路由中心，接收和分发事件
- **Trigger**: 事件过滤和路由规则，将特定类型的事件转发给消费者

> **特点**: 
> - 只使用 Knative Eventing，不依赖 Knative Serving
> - Producer 无需构建自定义镜像，使用 ConfigMap 注入代码
> - Consumer 无需构建自定义镜像，使用 ConfigMap 注入代码
> - 自动化事件生成，适合演示和测试

## 快速开始

### 前提条件

- Kubernetes 集群
- **仅需要** Knative Eventing (不需要 Knative Serving)
- kubectl 已配置 (无需 Docker！)

### 安装 Knative Eventing

```bash
# 安装 Knative Eventing CRDs
kubectl apply -f https://github.com/knative/eventing/releases/download/knative-v1.12.0/eventing-crds.yaml

# 安装 Knative Eventing 核心组件
kubectl apply -f https://github.com/knative/eventing/releases/download/knative-v1.12.0/eventing-core.yaml

# 安装 In-Memory Channel (用于开发测试)
kubectl apply -f https://github.com/knative/eventing/releases/download/knative-v1.12.0/in-memory-channel.yaml

# 安装 MT Channel Broker
kubectl apply -f https://github.com/knative/eventing/releases/download/knative-v1.12.0/mt-channel-broker.yaml
```

### 部署步骤

#### 方法1: 一键部署 (推荐)
   ```bash
   # 完整的部署流程 (无需 Docker!)
   ./scripts/deploy-all.sh
   ```

#### 方法2: 分步部署
1. **检查镜像状态** (无需构建，使用通用镜像)
   ```bash
   ./scripts/build-all.sh
   ```

2. **创建基础设施**
   ```bash
   cd infrastructure
   ./scripts/setup.sh
   ```

#### 快速测试
   ```bash
   # 自动化测试脚本
   ./scripts/quick-test.sh
   ```

#### 手动观察
   ```bash
   # 查看 Producer 日志 (自动发送事件)
   kubectl logs -f deployment/event-producer -n knative-demo
   
   # 查看 Consumer 日志 (处理事件)  
   kubectl logs -f deployment/event-consumer -n knative-demo
   
   # 查看事件详情
   kubectl get events -n knative-demo --sort-by='.lastTimestamp'
   ```

## 事件类型

项目支持以下事件类型：

- `demo.event` - 演示事件
- `user.created` - 用户创建事件
- `order.placed` - 订单创建事件

## 组件说明

### 🤖 自动化 Producer
- **镜像**: `python:3.11-slim` (通用镜像)
- **代码**: 通过 ConfigMap 注入
- **功能**: 每 10 秒自动发送一个事件
- **事件类型**: 轮流发送 `demo.event`、`user.created`、`order.placed`

### 🔧 智能 Consumer
- **镜像**: `python:3.11-slim` (通用镜像)
- **代码**: 通过 ConfigMap 注入
- **副本数**: 2 个实例并行处理
- **API 接口**:
  - `POST /` - 接收 CloudEvents (Knative 事件入口)
  - `GET /health` - 健康检查
  - `GET /metrics` - 指标信息
  - `GET /stats` - 详细统计信息

## 代码修改

如需修改应用逻辑：

1. **编辑 ConfigMap**:
   - Producer: `infrastructure/kubernetes/producer-configmap.yaml`
   - Consumer: `infrastructure/kubernetes/consumer-configmap.yaml`

2. **重新部署**:
   ```bash
   kubectl apply -f infrastructure/kubernetes/producer-configmap.yaml
   kubectl apply -f infrastructure/kubernetes/consumer-configmap.yaml
   kubectl rollout restart deployment/event-producer -n knative-demo
   kubectl rollout restart deployment/event-consumer -n knative-demo
   ```

## 监控和调试

```bash
# 查看所有资源
kubectl get all -n knative-demo

# 查看 Broker 状态
kubectl get broker -n knative-demo

# 查看 Trigger 状态
kubectl get trigger -n knative-demo

# 查看事件流
kubectl get events -n knative-demo --sort-by='.lastTimestamp'
```

## 清理环境

```bash
cd infrastructure
./scripts/cleanup.sh
```

## 技术栈

- **事件系统**: Knative Eventing
- **容器编排**: Kubernetes
- **基础镜像**: Python 3.11 Slim (官方镜像)
- **代码注入**: Kubernetes ConfigMap
- **Web 框架**: Flask + Gunicorn
- **事件标准**: CloudEvents
- **部署方式**: 零镜像构建 