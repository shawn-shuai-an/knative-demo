# Knative 事件驱动架构演示

## 🏗️ 架构概览

```
Producer → Broker → Trigger → Consumer
   |         |        |         |
生产事件   事件中心   路由规则   处理事件
```

## 📦 核心组件

### 1. Broker - 事件中心
```yaml
apiVersion: eventing.knative.dev/v1
kind: Broker
metadata:
  name: default
```
- **作用**: 接收所有事件，统一分发
- **特点**: 支持内存存储或 Kafka 持久化

### 2. Producer - 事件生产者
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: event-producer
```
- **作用**: 生产 `user.created`、`order.placed`、`payment.processed` 事件
- **协议**: CloudEvents 标准（HTTP headers + JSON body）

### 3. Consumer - 事件消费者
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: event-consumer
```
- **作用**: 接收并处理所有类型的事件
- **接口**: HTTP POST `/` 端点

### 4. Trigger - 事件路由
```yaml
apiVersion: eventing.knative.dev/v1
kind: Trigger
spec:
  broker: default
  filter:
    attributes:
      type: user.created  # 事件类型过滤
  subscriber:
    ref:
      kind: Service
      name: event-consumer-service
```
- **作用**: 根据事件类型过滤和路由
- **特点**: 每种事件类型一个 Trigger

## 🚀 快速使用

### 1. 部署
```bash
kubectl apply -f knative-demo-simple.yaml
```

### 2. 查看运行状态
```bash
# 查看所有组件
kubectl get all -n knative-demo

# 查看 Broker 状态
kubectl get broker -n knative-demo

# 查看 Trigger 状态
kubectl get trigger -n knative-demo
```

### 3. 查看日志
```bash
# Producer 日志（发送事件）
kubectl logs -f deployment/event-producer -n knative-demo

# Consumer 日志（接收事件）
kubectl logs -f deployment/event-consumer -n knative-demo
```

## 🔍 事件流程

1. **Producer** 每 5 秒发送一个事件到 **Broker**
2. **Broker** 接收事件并分发给匹配的 **Trigger**
3. **Trigger** 根据 `Ce-Type` 头过滤事件类型
4. 匹配的事件被路由到 **Consumer** 的 HTTP 端点
5. **Consumer** 处理事件并返回成功响应

## 📊 监控示例

```bash
# 查看 Consumer 健康状态
kubectl port-forward service/event-consumer-service 8080:80 -n knative-demo
curl http://localhost:8080/health
```

## 🔧 扩展配置

### 升级到 Kafka 后端
```yaml
# 在 Broker 中添加配置
spec:
  config:
    apiVersion: v1
    kind: ConfigMap
    name: kafka-broker-config
    namespace: knative-eventing
```

### 添加新的事件类型
1. 在 Producer 中添加新的 event_type
2. 创建对应的 Trigger 进行路由
3. Consumer 会自动处理新类型的事件

## ✨ 关键特性

- ✅ **零镜像构建**: 使用通用镜像 + 内嵌代码
- ✅ **标准协议**: 遵循 CloudEvents 规范
- ✅ **事件过滤**: 基于事件类型的智能路由
- ✅ **水平扩展**: Consumer 支持多副本
- ✅ **松耦合**: Producer 和 Consumer 完全解耦 