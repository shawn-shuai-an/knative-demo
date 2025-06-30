#!/bin/bash

# Knative 监控演示脚本
echo "📊 Knative 监控能力演示"
echo "======================"

NAMESPACE="knative-demo"

# 检查 Knative 组件状态
echo "🔍 检查 Knative 组件状态"
echo "========================"

echo "📋 Brokers:"
kubectl get brokers -n $NAMESPACE -o wide

echo ""
echo "📋 Triggers:"
kubectl get triggers -n $NAMESPACE -o wide

echo ""
echo "📋 Services:"
kubectl get services -n $NAMESPACE -o wide

echo ""

# 检查是否有 Prometheus 监控
echo "🔍 检查 Prometheus 监控配置"
echo "============================"

# 查找 ServiceMonitors
servicemonitors=$(kubectl get servicemonitors --all-namespaces 2>/dev/null | grep -i knative || echo "未找到 ServiceMonitors")
echo "ServiceMonitors: $servicemonitors"

# 查找 Prometheus 实例
prometheus_pods=$(kubectl get pods --all-namespaces | grep prometheus | head -3)
if [ -n "$prometheus_pods" ]; then
    echo "Prometheus Pods:"
    echo "$prometheus_pods"
else
    echo "❌ 未找到 Prometheus 实例"
fi

echo ""

# 检查应用自定义指标
echo "📊 检查应用自定义指标"
echo "===================="

# 检查 Consumer 的自定义指标端点
consumer_pods=$(kubectl get pods -n $NAMESPACE -l app=event-consumer -o name)

if [ -n "$consumer_pods" ]; then
    echo "找到 Consumer Pods:"
    for pod in $consumer_pods; do
        pod_name=$(echo $pod | cut -d'/' -f2)
        echo "  - $pod_name"
        
        # 尝试访问自定义指标端点
        echo "    📈 尝试获取 /metrics 端点:"
        metrics=$(kubectl exec $pod_name -n $NAMESPACE -- curl -s http://localhost:8080/metrics 2>/dev/null || echo "无法访问")
        if [ "$metrics" != "无法访问" ]; then
            echo "    ✅ 应用指标可用:"
            echo "$metrics" | head -10
        else
            echo "    ❌ 应用指标不可用"
        fi
        
        echo "    📈 尝试获取 /health 端点:"
        health=$(kubectl exec $pod_name -n $NAMESPACE -- curl -s http://localhost:8080/health 2>/dev/null || echo "无法访问")
        if [ "$health" != "无法访问" ]; then
            echo "    ✅ 健康检查可用:"
            echo "    $health"
        else
            echo "    ❌ 健康检查不可用"
        fi
        echo ""
    done
else
    echo "❌ 未找到 Consumer Pods"
fi

# 检查 Producer 状态
echo "📤 检查 Producer 状态"
echo "==================="

producer_pods=$(kubectl get pods -n $NAMESPACE -l app=event-producer -o name)

if [ -n "$producer_pods" ]; then
    echo "找到 Producer Pods:"
    for pod in $producer_pods; do
        pod_name=$(echo $pod | cut -d'/' -f2)
        echo "  - $pod_name"
        
        # 查看最近的发送日志
        echo "    📋 最近的发送日志:"
        kubectl logs $pod_name -n $NAMESPACE --tail=5 | grep -E "(发送|sent|event|publish)" || echo "    无相关日志"
        echo ""
    done
else
    echo "❌ 未找到 Producer Pods"
fi

# 模拟 Knative 官方指标（如果有 Prometheus）
echo "🎯 Knative 官方指标示例"
echo "======================"

echo "如果部署了 Prometheus，您可以查询以下指标："
echo ""
echo "📊 Broker 指标:"
echo "  event_count{broker_name=\"default\", namespace_name=\"knative-demo\"}"
echo "  event_dispatch_latencies{broker_name=\"default\", namespace_name=\"knative-demo\"}"
echo ""
echo "📊 Trigger 指标:"
echo "  event_count{trigger_name=\"demo-event-trigger\", namespace_name=\"knative-demo\"}"
echo "  event_processing_latencies{trigger_name=\"demo-event-trigger\", namespace_name=\"knative-demo\"}"
echo ""
echo "📊 Source 指标:"
echo "  event_count{event_source=\"event-producer\", namespace_name=\"knative-demo\"}"
echo "  retry_event_count{event_source=\"event-producer\", namespace_name=\"knative-demo\"}"

echo ""

# 对比 Dapr 指标
echo "🔄 对比：Dapr 可以直接获得的指标"
echo "================================"

echo "Dapr 在相同场景下可以直接获得："
echo ""
echo "📊 消息发布指标:"
echo "  dapr_component_pubsub_egress_count{app_id=\"producer\", topic=\"pod-events\"}"
echo "  dapr_component_pubsub_egress_latencies{app_id=\"producer\", topic=\"pod-events\"}"
echo ""
echo "📊 消息接收指标:"
echo "  dapr_component_pubsub_ingress_count{app_id=\"consumer\", topic=\"pod-events\"}"
echo "  dapr_component_pubsub_ingress_latencies{app_id=\"consumer\", topic=\"pod-events\"}"
echo ""
echo "📊 自动计算的业务指标:"
echo "  消息堆积 = egress_count - ingress_count"
echo "  消费速率 = rate(ingress_count[1m])"
echo "  处理延迟 = histogram_quantile(0.95, ingress_latencies)"

echo ""

# 总结
echo "📝 监控能力总结"
echo "=============="

echo "✅ Knative 优势:"
echo "  - 平台组件监控完整 (Broker, Trigger, Channel)"
echo "  - 事件路由和分发监控"
echo "  - 官方 Grafana Dashboard 支持"
echo ""
echo "❌ Knative 限制:"
echo "  - 需要手动实现应用层监控"
echo "  - 消息堆积计算复杂"
echo "  - 缺乏开箱即用的业务指标"
echo ""
echo "🎯 结论:"
echo "  对于您的需求（监控消息堆积和消费速度），"
echo "  Knative 需要更多的自定义开发工作。"

echo ""
echo "💡 建议:"
echo "  如果选择 Knative，需要:"
echo "  1. 部署 Prometheus + Grafana"
echo "  2. 配置 ServiceMonitor"
echo "  3. 在应用中实现详细的业务指标"
echo "  4. 创建自定义 Dashboard" 