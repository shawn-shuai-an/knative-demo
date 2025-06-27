#!/bin/bash

# Knative Demo 环境初始化脚本

set -e

echo "🚀 开始部署 Knative Demo 基础设施..."

# 检查 kubectl 是否可用
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl 未找到，请先安装 kubectl"
    exit 1
fi

# 检查 Knative Eventing 是否安装
if ! kubectl get crd brokers.eventing.knative.dev &> /dev/null; then
    echo "❌ Knative Eventing 未安装，请先安装 Knative Eventing"
    echo "参考: https://knative.dev/docs/install/"
    exit 1
fi

echo "✅ 环境检查通过"

# 创建命名空间
echo "📦 创建命名空间..."
kubectl apply -f knative/namespace.yaml

# 等待命名空间创建完成
## kubectl wait --for=condition=Ready namespace/knative-demo --timeout=30s

# 创建应用配置 ConfigMap
echo "🗂️  创建应用配置..."
kubectl apply -f kubernetes/producer-configmap.yaml
kubectl apply -f kubernetes/consumer-configmap.yaml

# 创建 Broker
echo "🔗 创建 Broker..."
kubectl apply -f knative/broker.yaml

# 等待 Broker 准备就绪
echo "⏱️  等待 Broker 准备就绪..."
kubectl wait --for=condition=Ready broker/default -n knative-demo --timeout=60s

# 创建应用服务 (Deployments 和 Services)
echo "🛠️  创建应用服务..."
kubectl apply -f knative/services.yaml

# 等待 Deployment 准备就绪
echo "⏱️  等待应用服务准备就绪..."
kubectl wait --for=condition=Available deployment/event-producer -n knative-demo --timeout=120s
kubectl wait --for=condition=Available deployment/event-consumer -n knative-demo --timeout=120s

# 创建 Trigger
echo "🎯 创建 Trigger..."
kubectl apply -f knative/trigger.yaml

# 等待 Trigger 准备就绪
echo "⏱️  等待 Trigger 准备就绪..."
kubectl wait --for=condition=Ready trigger/demo-event-trigger -n knative-demo --timeout=60s
kubectl wait --for=condition=Ready trigger/user-created-trigger -n knative-demo --timeout=60s
kubectl wait --for=condition=Ready trigger/order-placed-trigger -n knative-demo --timeout=60s

echo ""
echo "🎉 Knative Demo 基础设施部署完成！"
echo ""
echo "📊 部署状态:"
echo "命名空间: $(kubectl get ns knative-demo -o jsonpath='{.status.phase}')"
echo "Broker: $(kubectl get broker default -n knative-demo -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')"
echo "Producer 部署: $(kubectl get deployment event-producer -n knative-demo -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')"
echo "Consumer 部署: $(kubectl get deployment event-consumer -n knative-demo -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')"
echo ""
echo "🔗 服务信息:"
kubectl get deployments,services,configmap -n knative-demo
echo ""
echo "📋 查看实时日志:"
echo "# Producer 日志 (自动发送事件):"
echo "kubectl logs -f deployment/event-producer -n knative-demo"
echo ""
echo "# Consumer 日志 (处理事件):"
echo "kubectl logs -f deployment/event-consumer -n knative-demo"
echo ""
echo "⚙️  配置信息:"
echo "- Producer 每 10 秒自动发送一个事件"
echo "- Consumer 运行 2 个副本处理事件"
echo "- 支持三种事件类型: demo.event, user.created, order.placed"
echo ""
echo "🔗 服务信息:"
kubectl get deployments,services -n knative-demo
echo ""
echo "💡 测试命令 (需要端口转发):"
echo "kubectl port-forward service/event-producer-service 8080:80 -n knative-demo"
echo "curl -X POST http://localhost:8080/produce \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"message\": \"Hello Knative!\"}'" 