# Dapr 事件驱动架构演示

## 🏗️ 架构概览

```
Producer → Dapr Sidecar → Pub/Sub Component → Dapr Sidecar → Consumer
   |           |               |                   |            |
生产事件    Sidecar代理      消息队列          Sidecar代理    处理事件
```

## 📦 核心组件

### 1. Pub/Sub Component - 消息队列组件
```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: pubsub
spec:
  type: pubsub.redis
  metadata:
  - name: redisHost
    value: "redis-master.default.svc.cluster.local:6379"
```
- **作用**: 定义消息队列后端（Redis/Kafka）
- **特点**: 支持多种消息队列系统

### 2. Producer - 事件生产者
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: event-producer
  annotations:
    dapr.io/enabled: "true"
    dapr.io/app-id: "event-producer"
    dapr.io/app-port: "6000"
```
- **作用**: 生产 `user.created`、`order.placed`、`payment.processed` 事件
- **协议**: Dapr HTTP API (`/v1.0/publish/{pubsub}/{topic}`)
- **特点**: 自动注入 Dapr sidecar

### 3. Consumer - 事件消费者
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: event-consumer
  annotations:
    dapr.io/enabled: "true"
    dapr.io/app-id: "event-consumer"
    dapr.io/app-port: "6001"
```
- **作用**: 接收并处理所有类型的事件
- **接口**: 提供 `/dapr/subscribe` 端点配置订阅
- **路由**: 每种事件类型对应不同的 HTTP 路由

### 4. Sidecar - 服务代理
```yaml
# 通过 annotations 自动注入
dapr.io/enabled: "true"
dapr.io/app-id: "event-producer"
dapr.io/app-port: "6000"
```
- **作用**: 处理与 Pub/Sub 的通信，提供服务发现
- **特点**: 每个 Pod 自动注入一个 sidecar 容器

## 🚀 快速使用

### 1. 安装 Dapr
```bash
# 安装 Dapr CLI
curl -fsSL https://raw.githubusercontent.com/dapr/cli/master/install/install.sh | /bin/bash

# 初始化 Dapr 到 Kubernetes
dapr init -k
```

### 2. 部署演示
```bash
kubectl apply -f dapr-demo-simple.yaml
```

### 3. 查看运行状态
```bash
# 查看所有组件
kubectl get all -n dapr-demo

# 查看 Dapr Component
kubectl get component -n dapr-demo

# 查看 sidecar 注入情况
kubectl describe pod -n dapr-demo
```

### 4. 查看日志
```bash
# Producer 日志（发送事件）
kubectl logs -f deployment/event-producer -c event-producer -n dapr-demo

# Producer sidecar 日志
kubectl logs -f deployment/event-producer -c daprd -n dapr-demo

# Consumer 日志（接收事件）
kubectl logs -f deployment/event-consumer -c event-consumer -n dapr-demo

# Consumer sidecar 日志
kubectl logs -f deployment/event-consumer -c daprd -n dapr-demo
```

## 🔍 事件流程

1. **Producer** 每 5 秒发送事件到本地 **Dapr sidecar** (`localhost:3500`)
2. **Producer sidecar** 通过 **Pub/Sub Component** 发送到 **Redis**
3. **Consumer sidecar** 从 **Redis** 拉取事件
4. **Consumer sidecar** 根据订阅配置路由到相应的 HTTP 端点
5. **Consumer** 处理事件并返回 `{"status": "SUCCESS"}`

## 📊 监控示例

```bash
# 查看 Consumer 健康状态
kubectl port-forward service/event-consumer-service 8080:80 -n dapr-demo
curl http://localhost:8080/health

# 查看 Dapr Dashboard
dapr dashboard -k
```

## 🔧 扩展配置

### 升级到 Kafka 后端
```yaml
# 修改 Pub/Sub Component
spec:
  type: pubsub.kafka
  metadata:
  - name: brokers
    value: "kafka.default.svc.cluster.local:9092"
  - name: consumerGroup
    value: "dapr-consumer-group"
```

### 添加新的事件类型
1. 在 Producer 中添加新的 topic
2. 在 Consumer 的 `/dapr/subscribe` 端点添加新订阅
3. 在 Consumer 中实现对应的处理路由

## ✨ 关键特性

- ✅ **零镜像构建**: 使用通用镜像 + 内嵌代码
- ✅ **自动 Sidecar**: 通过 annotations 自动注入
- ✅ **多后端支持**: 支持 Redis、Kafka、RabbitMQ 等
- ✅ **服务发现**: Sidecar 提供自动服务发现
- ✅ **竞争消费**: 同一 Consumer Group 内竞争处理

## 🆚 与 Knative 对比

| 特性 | Dapr | Knative |
|------|------|---------|
| **架构模式** | Sidecar 代理 | 直接通信 |
| **事件协议** | Dapr HTTP API | CloudEvents 标准 |
| **消费模式** | 竞争消费 | 事件扇出 |
| **配置方式** | 代码内订阅 | 声明式 Trigger |
| **容器数量** | 应用 + Sidecar | 仅应用 |
| **服务发现** | 自动提供 | 需要 K8s Service | 