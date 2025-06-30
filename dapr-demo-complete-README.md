# Dapr 完整事件驱动架构演示

## 🏗️ 完整架构概览

```
Producer (SDK) → Dapr Sidecar → Pub/Sub Component → Dapr Sidecar → Consumer
     |               |               |                   |            |
  使用SDK         自动发现        Redis/Kafka        自动拉取     处理事件
```

## 📦 完整组件配置

### 1. Producer - 使用 Dapr SDK (推荐)

#### ConfigMap + Deployment 配置
```yaml
# Producer ConfigMap - 包含完整的 Python 代码
apiVersion: v1
kind: ConfigMap
metadata:
  name: producer-code
  namespace: dapr-demo
data:
  main.py: |
    from dapr.clients import DaprClient
    
    # 使用 SDK - 无需指定 localhost:3500
    with DaprClient() as dapr_client:
        dapr_client.publish_event(
            pubsub_name="pubsub",
            topic_name="user.created",
            data=json.dumps(event_data)
        )

# Producer Deployment - 注入 sidecar
apiVersion: apps/v1
kind: Deployment
metadata:
  name: event-producer
spec:
  template:
    metadata:
      annotations:
        dapr.io/enabled: "true"
        dapr.io/app-id: "event-producer"
        dapr.io/app-port: "6000"
```

#### SDK vs HTTP API 对比
| 方式 | 代码示例 | 优势 | 劣势 |
|------|---------|------|------|
| **Dapr SDK** | `dapr_client.publish_event()` | ✅ 自动发现 sidecar<br/>✅ 类型安全<br/>✅ 错误处理 | ❌ 需要安装依赖 |
| **HTTP API** | `requests.post('localhost:3500/v1.0/publish/...')` | ✅ 无依赖<br/>✅ 语言无关 | ❌ 硬编码地址<br/>❌ 手动错误处理 |

### 2. Consumer - 完整实现

#### ConfigMap + Deployment 配置
```yaml
# Consumer ConfigMap - 包含完整的 Flask 应用
apiVersion: v1
kind: ConfigMap
metadata:
  name: consumer-code
  namespace: dapr-demo
data:
  main.py: |
    @app.route('/dapr/subscribe', methods=['GET'])
    def subscribe():
        return jsonify([
            {"pubsubname": "pubsub", "topic": "user.created", "route": "/user-events"},
            {"pubsubname": "pubsub", "topic": "order.placed", "route": "/order-events"},
            {"pubsubname": "pubsub", "topic": "payment.processed", "route": "/payment-events"}
        ])

# Consumer Deployment - 2 副本 + sidecar
apiVersion: apps/v1
kind: Deployment
metadata:
  name: event-consumer
spec:
  replicas: 2
  template:
    metadata:
      annotations:
        dapr.io/enabled: "true"
        dapr.io/app-id: "event-consumer"  
        dapr.io/app-port: "6001"
```

#### Consumer 关键端点
- **`/dapr/subscribe`** - 订阅配置（Dapr 自动调用）
- **`/user-events`** - 处理用户事件
- **`/order-events`** - 处理订单事件  
- **`/payment-events`** - 处理支付事件
- **`/health`** - 健康检查
- **`/stats`** - 详细统计

### 3. Pub/Sub Component
```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: pubsub
  namespace: dapr-demo
spec:
  type: pubsub.redis
  metadata:
  - name: redisHost
    value: "redis-master.default.svc.cluster.local:6379"
```

### 4. Redis 后端
```yaml
# Redis Deployment + Service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
spec:
  containers:
  - name: redis
    image: redis:7-alpine
    args: ["redis-server", "--appendonly", "yes"]
```

## 🚀 快速部署

### 1. 前置条件
```bash
# 安装 Dapr CLI
curl -fsSL https://raw.githubusercontent.com/dapr/cli/master/install/install.sh | /bin/bash

# 初始化 Dapr 到 Kubernetes
dapr init -k

# 验证 Dapr 安装
dapr status -k
```

### 2. 一键部署
```bash
kubectl apply -f dapr-demo-complete.yaml
```

### 3. 验证部署
```bash
# 查看所有 Pod（注意每个 Pod 有 2 个容器）
kubectl get pods -n dapr-demo

# 查看 Component
kubectl get component -n dapr-demo

# 查看 sidecar 注入情况
kubectl describe pod -l app=producer -n dapr-demo
```

## 🔍 监控和调试

### 1. 查看日志（区分应用和 sidecar）
```bash
# Producer 应用日志
kubectl logs -f deployment/event-producer -c event-producer -n dapr-demo

# Producer sidecar 日志
kubectl logs -f deployment/event-producer -c daprd -n dapr-demo

# Consumer 应用日志
kubectl logs -f deployment/event-consumer -c event-consumer -n dapr-demo

# Consumer sidecar 日志
kubectl logs -f deployment/event-consumer -c daprd -n dapr-demo
```

### 2. 健康检查
```bash
# 应用健康检查
kubectl port-forward service/event-consumer-service 8080:80 -n dapr-demo
curl http://localhost:8080/health

# 详细统计
curl http://localhost:8080/stats
```

### 3. Dapr Dashboard
```bash
# 启动 Dapr Dashboard
dapr dashboard -k

# 访问 http://localhost:8080 查看：
# - 应用状态
# - Component 状态  
# - 指标信息
```

## 📊 事件流程详解

### 1. 生产流程
```
Producer App → Dapr SDK → Producer Sidecar → Pub/Sub Component → Redis
     |            |             |                    |            |
  业务代码     自动发现      HTTP/gRPC 转换        组件抽象     存储
```

### 2. 消费流程
```
Redis → Pub/Sub Component → Consumer Sidecar → HTTP 调用 → Consumer App
  |           |                    |              |            |
存储      组件抽象           订阅管理        路由分发      业务处理
```

### 3. 订阅机制
1. **Consumer 启动** → Dapr sidecar 调用 `/dapr/subscribe`
2. **返回订阅配置** → 告诉 Dapr 要订阅哪些 Topic
3. **Sidecar 订阅** → 连接到 Redis 开始拉取消息
4. **消息路由** → 根据 Topic 路由到对应的 HTTP 端点
5. **应用处理** → 返回 `{"status": "SUCCESS"}` 确认处理

## ✨ 关键特性展示

### 1. SDK 自动发现
```python
# ✅ 使用 SDK - 自动发现 sidecar
with DaprClient() as dapr_client:
    dapr_client.publish_event(
        pubsub_name="pubsub",
        topic_name="user.created", 
        data=json.dumps(event_data)
    )

# ❌ 硬编码 HTTP - 需要指定地址
requests.post('http://localhost:3500/v1.0/publish/pubsub/user.created', 
              json=event_data)
```

### 2. 消费者组配置
```json
{
  "pubsubname": "pubsub",
  "topic": "user.created",
  "route": "/user-events", 
  "metadata": {
    "consumerGroup": "user-processors"  // 竞争消费配置
  }
}
```

### 3. 完整的错误处理
```python
try:
    # 处理事件
    return jsonify({"status": "SUCCESS"}), 200
except Exception as e:
    # Dapr 会自动重试
    return jsonify({"status": "RETRY", "error": str(e)}), 500
```

## 🆚 与 Knative 完整对比

| 特性 | Dapr (完整版) | Knative |
|------|---------------|---------|
| **配置复杂度** | ConfigMap + Deployment + Component | ConfigMap + Deployment + Broker + Trigger |
| **容器监控** | 应用容器 + Sidecar 容器 | 仅应用容器 |
| **事件协议** | Dapr HTTP API | CloudEvents 标准 |
| **订阅配置** | 代码内 `/dapr/subscribe` 端点 | 声明式 Trigger |
| **消费模式** | 竞争消费（Consumer Group） | 事件扇出（多播） |
| **SDK 支持** | ✅ 丰富的 SDK 支持 | ❌ 主要是 HTTP |
| **调试复杂度** | 需要区分应用和 sidecar 日志 | 单一日志源 |

## 🎯 演示亮点

- ✅ **SDK 最佳实践**: 展示 Dapr SDK 的正确用法
- ✅ **完整的 YAML**: 包含所有必要的 K8s 资源
- ✅ **零镜像构建**: 代码通过 ConfigMap 注入
- ✅ **生产就绪**: 包含资源限制、健康检查等
- ✅ **可观测性**: 详细的日志和统计端点
- ✅ **竞争消费**: 演示 Consumer Group 机制

这个完整版本展示了 Dapr 在生产环境中的实际使用方式，特别适合技术评估和架构对比！ 