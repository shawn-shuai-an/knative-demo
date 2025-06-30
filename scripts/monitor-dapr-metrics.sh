#!/bin/bash

echo "📊 Dapr 指标监控工具"
echo "====================="

NAMESPACE="dapr-demo"

# 检查 Dapr sidecar 是否启用了指标
echo "🔍 检查 Dapr 指标端点..."

# 获取所有启用了 Dapr 的 Pods
pods=$(kubectl get pods -n $NAMESPACE -l dapr.io/enabled=true -o name)

if [ -z "$pods" ]; then
    echo "❌ 没有找到启用了 Dapr 的 Pods"
    exit 1
fi

echo "找到以下 Dapr-enabled Pods:"
for pod in $pods; do
    pod_name=$(echo $pod | cut -d'/' -f2)
    echo "  - $pod_name"
done
echo ""

# 监控函数
monitor_pod_metrics() {
    local pod_name=$1
    echo "📈 Pod: $pod_name"
    echo "=================="
    
    # 检查 Pod 状态
    echo "🔋 Pod 状态:"
    kubectl get pod $pod_name -n $NAMESPACE -o wide
    echo ""
    
    # 检查 Dapr sidecar 日志中的关键指标
    echo "📊 Dapr Sidecar 最近日志:"
    kubectl logs $pod_name -n $NAMESPACE -c daprd --tail=10 | grep -E "(published|received|error|failed)" || echo "没有找到相关日志"
    echo ""
    
    # 尝试获取指标端点（如果可访问）
    echo "🌐 尝试获取 Dapr 指标:"
    kubectl exec $pod_name -n $NAMESPACE -c daprd -- curl -s http://localhost:9090/metrics 2>/dev/null | grep -E "(dapr_|http_)" | head -10 || echo "指标端点不可访问"
    echo ""
    
    # 应用容器日志中的消息统计
    echo "📨 应用日志中的消息统计:"
    app_logs=$(kubectl logs $pod_name -n $NAMESPACE -c app --tail=50 2>/dev/null)
    if [ -n "$app_logs" ]; then
        published_count=$(echo "$app_logs" | grep -c "Published message" || echo "0")
        received_count=$(echo "$app_logs" | grep -c "Received event" || echo "0")
        echo "  发布消息数: $published_count"
        echo "  接收消息数: $received_count"
    else
        echo "  无法获取应用日志"
    fi
    echo ""
}

# 实时监控所有 Pods
realtime_monitor_all() {
    echo "🚀 实时监控所有 Dapr Pods"
    echo "Press Ctrl+C to stop"
    echo ""
    
    while true; do
        clear
        echo "🕐 $(date)"
        echo "======================================================"
        
        for pod in $pods; do
            pod_name=$(echo $pod | cut -d'/' -f2)
            
            # 基本状态
            status=$(kubectl get pod $pod_name -n $NAMESPACE -o jsonpath='{.status.phase}')
            ready=$(kubectl get pod $pod_name -n $NAMESPACE -o jsonpath='{.status.containerStatuses[?(@.name=="app")].ready}')
            dapr_ready=$(kubectl get pod $pod_name -n $NAMESPACE -o jsonpath='{.status.containerStatuses[?(@.name=="daprd")].ready}')
            
            echo "📱 $pod_name: Status=$status, App=$ready, Dapr=$dapr_ready"
            
            # 最近的消息活动
            recent_logs=$(kubectl logs $pod_name -n $NAMESPACE -c app --tail=5 --since=10s 2>/dev/null | grep -E "(Published|Received)" | wc -l)
            echo "  最近10秒消息活动: $recent_logs 条"
            
            # 错误检查
            error_logs=$(kubectl logs $pod_name -n $NAMESPACE -c daprd --tail=10 --since=30s 2>/dev/null | grep -i error | wc -l)
            if [ "$error_logs" -gt 0 ]; then
                echo "  ⚠️  最近30秒有 $error_logs 个错误"
            fi
            
            echo ""
        done
        
        sleep 5
    done
}

# 详细的消息流监控
monitor_message_flow() {
    echo "🌊 消息流监控"
    echo "============="
    
    for pod in $pods; do
        pod_name=$(echo $pod | cut -d'/' -f2)
        echo "📱 监控 $pod_name 的消息流:"
        
        # 启动后台日志监控
        (kubectl logs $pod_name -n $NAMESPACE -c app -f 2>/dev/null | while read line; do
            if echo "$line" | grep -q "Published message"; then
                echo "  📤 [$pod_name] $line"
            elif echo "$line" | grep -q "Received event"; then
                echo "  📥 [$pod_name] $line"
            fi
        done) &
        
        echo "  日志监控已启动 (PID: $!)"
    done
    
    echo ""
    echo "🚀 实时消息流监控已启动，按 Ctrl+C 停止"
    wait
}

# Redis 连接检查
check_redis_connectivity() {
    echo "🔌 检查 Redis 连接性"
    echo "==================="
    
    for pod in $pods; do
        pod_name=$(echo $pod | cut -d'/' -f2)
        echo "📱 $pod_name Redis 连接测试:"
        
        # 从 Pod 内部测试 Redis 连接
        kubectl exec $pod_name -n $NAMESPACE -c app -- nc -zv 172.22.131.59 6379 2>/dev/null && echo "  ✅ Redis 连接正常" || echo "  ❌ Redis 连接失败"
        
        # 检查 Dapr 组件状态
        echo "  Dapr 组件状态:"
        kubectl logs $pod_name -n $NAMESPACE -c daprd --tail=20 | grep -i "pubsub" | tail -3 || echo "    无相关日志"
        echo ""
    done
}

# 主菜单
echo "选择监控模式："
echo "1) 查看所有 Pod 详细指标"
echo "2) 实时监控所有 Pods"
echo "3) 消息流实时监控"
echo "4) Redis 连接检查"
echo "5) 显示 Dapr 组件状态"
read -p "请选择 (1-5): " choice

case $choice in
    1)
        for pod in $pods; do
            pod_name=$(echo $pod | cut -d'/' -f2)
            monitor_pod_metrics "$pod_name"
            echo "======================================"
        done
        ;;
    2)
        realtime_monitor_all
        ;;
    3)
        monitor_message_flow
        ;;
    4)
        check_redis_connectivity
        ;;
    5)
        echo "📋 Dapr 组件状态:"
        kubectl get components -n $NAMESPACE
        echo ""
        echo "📋 Dapr 组件详情:"
        kubectl describe components -n $NAMESPACE
        ;;
esac 