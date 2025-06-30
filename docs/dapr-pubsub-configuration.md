# Dapr Pub/Sub 组件配置指南

## 概述

Dapr支持多种Pub/Sub组件，包括Redis、Kafka、Azure Service Bus等。您可以使用现有的Redis实例，无需创建新的。

## 使用现有Redis配置Pub/Sub

### 1. 获取Redis连接信息

首先需要确认您现有Redis的连接信息：

```bash
# 如果Redis在Kubernetes集群内
kubectl get svc | grep redis

# 如果Redis在集群外，需要知道：
# - Redis主机地址和端口
# - 认证信息（如果有密码）
# - 是否启用TLS
```

### 2. 创建Redis Pub/Sub Component

#### 场景1：Redis在同一K8s集群内

```yaml
# redis-pubsub.yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: pubsub
  namespace: default  # 可以根据需要修改namespace
spec:
  type: pubsub.redis
  version: v1
  metadata:
  # 基础连接配置
  - name: redisHost
    value: "redis-service:6379"  # 替换为您的Redis服务名和端口
  - name: redisPassword
    value: ""  # 如果有密码，在这里设置
  - name: redisDB
    value: "0"  # Redis数据库号，默认0
    
  # 性能优化配置
  - name: enableTLS
    value: "false"  # 如果Redis启用了TLS，设置为true
  - name: maxRetries
    value: "3"
  - name: maxRetryBackoff
    value: "2s"
  - name: failover
    value: "false"  # 如果是Redis Sentinel模式，设置为true
    
  # Pub/Sub特定配置
  - name: concurrency
    value: "10"  # 并发消费者数量
  - name: processingTimeout
    value: "15s"  # 消息处理超时时间
  - name: redeliverInterval
    value: "60s"  # 消息重投递间隔
```

#### 场景2：Redis在集群外部

```yaml
# external-redis-pubsub.yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: pubsub
  namespace: default
spec:
  type: pubsub.redis
  version: v1
  metadata:
  - name: redisHost
    value: "your-redis-host.com:6379"  # 外部Redis地址
  - name: redisPassword
    value: "your-redis-password"  # Redis密码
  - name: redisDB
    value: "0"
  - name: enableTLS
    value: "true"  # 外部Redis通常启用TLS
  - name: concurrency
    value: "10"
  - name: processingTimeout
    value: "15s"
```

#### 场景3：使用Kubernetes Secret存储敏感信息

```yaml
# 首先创建Secret
apiVersion: v1
kind: Secret
metadata:
  name: redis-secret
  namespace: default
type: Opaque
data:
  password: eW91ci1yZWRpcy1wYXNzd29yZA==  # base64编码的密码
---
# 然后在Component中引用
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: pubsub
  namespace: default
spec:
  type: pubsub.redis
  version: v1
  metadata:
  - name: redisHost
    value: "redis-service:6379"
  - name: redisPassword
    secretKeyRef:
      name: redis-secret
      key: password
  - name: redisDB
    value: "0"
```

### 3. 部署Pub/Sub组件

```bash
# 部署组件配置
kubectl apply -f redis-pubsub.yaml

# 验证组件状态
kubectl get components

# 检查组件详情
kubectl describe component pubsub
```

## 创建测试应用验证Pub/Sub

### 1. 生产者应用

```yaml
# producer-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pub-producer
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: producer
  template:
    metadata:
      labels:
        app: producer
      annotations:
        dapr.io/enabled: "true"
        dapr.io/app-id: "producer"
        dapr.io/app-port: "8080"
    spec:
      containers:
      - name: producer
        image: nginx:alpine
        ports:
        - containerPort: 8080
        command: ["/bin/sh"]
        args:
        - -c
        - |
          cat > /tmp/test-producer.sh << 'EOF'
          #!/bin/sh
          counter=1
          while true; do
            # 发送消息到Dapr sidecar
            curl -X POST http://localhost:3500/v1.0/publish/pubsub/pod-events \
              -H "Content-Type: application/json" \
              -d "{\"message\": \"Test message $counter\", \"timestamp\": \"$(date)\"}"
            echo "Published message $counter"
            counter=$((counter + 1))
            sleep 5
          done
          EOF
          chmod +x /tmp/test-producer.sh
          /tmp/test-producer.sh
---
apiVersion: v1
kind: Service
metadata:
  name: producer-service
spec:
  selector:
    app: producer
  ports:
  - port: 8080
    targetPort: 8080
```

### 2. 消费者应用

```go
// consumer/main.go
package main

import (
    "context"
    "encoding/json"
    "log"
    "net/http"
    
    "github.com/dapr/go-sdk/service/common"
    daprd "github.com/dapr/go-sdk/service/http"
)

type PodEvent struct {
    Message   string `json:"message"`
    Timestamp string `json:"timestamp"`
}

func main() {
    service := daprd.NewService(":8080")
    
    // 订阅pod-events topic
    service.AddTopicEventHandler(&common.Subscription{
        PubsubName: "pubsub",
        Topic:      "pod-events",
        Route:      "/pod-events",
    }, handlePodEvents)
    
    // 健康检查端点
    service.AddServiceInvocationHandler("/health", func(ctx context.Context, in *common.InvocationEvent) (*common.Content, error) {
        return &common.Content{
            ContentType: "application/json",
            Data:        []byte(`{"status": "healthy"}`),
        }, nil
    })
    
    log.Println("Consumer service starting on port 8080")
    log.Fatal(service.Start())
}

func handlePodEvents(ctx context.Context, e *common.TopicEvent) (retry bool, err error) {
    var event PodEvent
    
    if err := json.Unmarshal(e.RawData, &event); err != nil {
        log.Printf("Failed to unmarshal event: %v", err)
        return false, err
    }
    
    log.Printf("🔥 Received event: %s at %s", event.Message, event.Timestamp)
    
    // 模拟处理时间
    // time.Sleep(100 * time.Millisecond)
    
    return false, nil
}
```

### 3. 消费者应用部署配置

```yaml
# consumer-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pub-consumer
  namespace: default
spec:
  replicas: 2  # 部署2个消费者实例测试负载均衡
  selector:
    matchLabels:
      app: consumer
  template:
    metadata:
      labels:
        app: consumer
      annotations:
        dapr.io/enabled: "true"
        dapr.io/app-id: "consumer"
        dapr.io/app-port: "8080"
    spec:
      containers:
      - name: consumer
        image: your-registry/consumer:latest  # 需要构建并推送镜像
        ports:
        - containerPort: 8080
        env:
        - name: APP_PORT
          value: "8080"
---
apiVersion: v1
kind: Service
metadata:
  name: consumer-service
spec:
  selector:
    app: consumer
  ports:
  - port: 8080
    targetPort: 8080
```

## 验证Pub/Sub功能

### 1. 检查组件状态

```bash
# 查看Dapr组件
kubectl get components

# 检查组件日志
kubectl logs -n dapr-system -l app=dapr-operator

# 查看应用的sidecar日志
kubectl logs deployment/pub-producer -c daprd
kubectl logs deployment/pub-consumer -c daprd
```

### 2. 测试消息发布

```bash
# 方式1：通过kubectl exec发送消息
kubectl exec deployment/pub-producer -c producer -- \
  curl -X POST http://localhost:3500/v1.0/publish/pubsub/pod-events \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello from kubectl", "timestamp": "2024-01-01T10:00:00Z"}'

# 方式2：通过端口转发发送消息
kubectl port-forward deployment/pub-producer 3500:3500 &
curl -X POST http://localhost:3500/v1.0/publish/pubsub/pod-events \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello from localhost", "timestamp": "2024-01-01T10:00:00Z"}'
```

### 3. 查看消费者日志

```bash
# 查看消费者应用日志
kubectl logs deployment/pub-consumer -c consumer -f

# 应该看到类似输出：
# 🔥 Received event: Hello from kubectl at 2024-01-01T10:00:00Z
```

## 高级配置

### 1. 多Topic配置

```go
// 消费者可以订阅多个topic
service.AddTopicEventHandler(&common.Subscription{
    PubsubName: "pubsub",
    Topic:      "pod-events",
    Route:      "/pod-events",
}, handlePodEvents)

service.AddTopicEventHandler(&common.Subscription{
    PubsubName: "pubsub", 
    Topic:      "deployment-events",
    Route:      "/deployment-events",
}, handleDeploymentEvents)
```

### 2. 消息过滤

```yaml
# 在订阅中添加过滤条件
apiVersion: dapr.io/v1alpha1
kind: Subscription
metadata:
  name: pod-events-subscription
spec:
  topic: pod-events
  route: /pod-events
  pubsubname: pubsub
  metadata:
    rawPayload: "true"
  rules:
  - match: event.type == "pod.created"
    path: /pod-created
  - match: event.type == "pod.deleted"  
    path: /pod-deleted
```

### 3. 死信队列配置

```yaml
# 在Component中添加死信队列配置
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: pubsub
spec:
  type: pubsub.redis
  version: v1
  metadata:
  - name: redisHost
    value: "redis-service:6379"
  - name: maxRedeliveryCount
    value: "3"  # 最大重试次数
  - name: processingTimeout
    value: "15s"
  - name: redeliverInterval
    value: "60s"
```

## 监控和故障排查

### 1. 使用Dapr Dashboard

```bash
# 端口转发到Dashboard
kubectl port-forward svc/dapr-dashboard -n dapr-system 8080:8080

# 访问 http://localhost:8080 查看：
# - 组件状态
# - 应用列表  
# - 消息流量统计
```

### 2. 检查Redis中的数据

```bash
# 如果Redis在集群内
kubectl exec -it your-redis-pod -- redis-cli

# 查看Pub/Sub相关的key
> KEYS *dapr*
> PUBSUB CHANNELS

# 查看消息队列
> LLEN "dapr:consumer:pubsub:pod-events"
```

### 3. 常见问题排查

```bash
# 组件无法连接Redis
kubectl describe component pubsub
kubectl logs -n dapr-system -l app=dapr-operator

# Sidecar注入失败
kubectl describe pod pub-producer
kubectl get mutatingwebhookconfiguration dapr-sidecar-injector

# 消息发布失败
kubectl logs deployment/pub-producer -c daprd
curl -v http://localhost:3500/v1.0/healthz
```

## 与Knative对比测试

现在您有了Dapr的Pub/Sub配置，可以：

1. **创建相同的业务逻辑** - 用Dapr实现之前的K8s Informer场景
2. **性能对比测试** - 在相同负载下比较两种架构的表现
3. **功能对比** - 体验两种平台的开发和运维差异

您现有的Redis完全可以直接使用，只需要在Component配置中指定正确的连接信息即可！ 