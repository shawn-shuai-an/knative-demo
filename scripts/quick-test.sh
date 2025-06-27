#!/bin/bash

# 快速测试脚本 - 验证自动化事件流

set -e

echo "🧪 开始快速测试 Knative Demo..."

# 检查命名空间是否存在
if ! kubectl get namespace knative-demo &> /dev/null; then
    echo "❌ 命名空间 knative-demo 不存在，请先运行部署脚本"
    exit 1
fi

# 检查服务是否运行
echo "🔍 检查服务状态..."
kubectl get deployments,services,broker,trigger,configmap -n knative-demo

echo ""
echo "📊 Producer 状态:"
kubectl get pods -l app=event-producer -n knative-demo

echo ""  
echo "📊 Consumer 状态:"
kubectl get pods -l app=event-consumer -n knative-demo

echo ""
echo "📋 查看最近的 Producer 日志 (自动发送事件):"
kubectl logs --tail=10 deployment/event-producer -n knative-demo || echo "⚠️  Producer 日志暂时不可用"

echo ""
echo "📋 查看最近的 Consumer 日志 (处理事件):"
kubectl logs --tail=10 deployment/event-consumer -n knative-demo || echo "⚠️  Consumer 日志暂时不可用"

echo ""
echo "⏱️  等待 30 秒，观察事件流..."
echo "   (Producer 每 10 秒发送一个事件)"

# 等待并显示实时日志
timeout 30s kubectl logs -f deployment/event-consumer -n knative-demo || echo ""

echo ""
echo "🎯 事件统计:"
echo "最近发送的事件类型:"
kubectl logs deployment/event-producer -n knative-demo --tail=50 | grep "Event sent" | tail -5 || echo "⚠️  暂无事件记录"

echo ""
echo "最近处理的事件:"
kubectl logs deployment/event-consumer -n knative-demo --tail=50 | grep "Received event" | tail -5 || echo "⚠️  暂无处理记录"

echo ""
echo "✅ 快速测试完成！"
echo ""
echo "💡 继续观察："
echo "# 实时查看 Producer 日志:"
echo "kubectl logs -f deployment/event-producer -n knative-demo"
echo ""
echo "# 实时查看 Consumer 日志:"
echo "kubectl logs -f deployment/event-consumer -n knative-demo"
echo ""
echo "# 查看事件详情:"
echo "kubectl get events -n knative-demo --sort-by='.lastTimestamp'" 