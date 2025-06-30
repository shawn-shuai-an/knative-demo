#!/bin/bash

# Dapr 指标监控工具 - 使用 Dapr 内置指标
NAMESPACE="dapr-demo"

echo "📊 Dapr 内置指标监控"
echo "====================="

# 获取所有启用了 Dapr 的 Pods
get_dapr_pods() {
    kubectl get pods -n $NAMESPACE -l dapr.io/sidecar-injected=true -o jsonpath='{.items[*].metadata.name}'
}

# 从指定Pod获取指标
get_metrics_from_pod() {
    local pod_name=$1
    local port=$2
    
    # 启动后台端口转发
    kubectl port-forward -n $NAMESPACE $pod_name $port:9090 >/dev/null 2>&1 &
    local pf_pid=$!
    
    # 等待端口转发建立
    sleep 2
    
    # 获取指标
    local metrics=$(curl -s http://localhost:$port/metrics 2>/dev/null)
    
    # 清理端口转发
    kill $pf_pid >/dev/null 2>&1
    
    echo "$metrics"
}

# 解析 pub/sub 指标
parse_pubsub_metrics() {
    local metrics="$1"
    local pod_name="$2"
    
    echo "📱 Pod: $pod_name"
    echo "==================="
    
    # 发布指标 (Egress)
    echo "📤 发布指标 (Egress):"
    local egress_count=$(echo "$metrics" | grep "dapr_component_pubsub_egress_count" | grep -v "^#" | awk -F' ' '{print $2}' | head -1)
    echo "  总发布消息数: ${egress_count:-0}"
    
    # 发布延迟统计
    local egress_p50=$(echo "$metrics" | grep "dapr_component_pubsub_egress_latencies" | grep 'le="5"' | awk -F' ' '{print $2}' | head -1)
    local egress_p95=$(echo "$metrics" | grep "dapr_component_pubsub_egress_latencies" | grep 'le="50"' | awk -F' ' '{print $2}' | head -1)
    local egress_p99=$(echo "$metrics" | grep "dapr_component_pubsub_egress_latencies" | grep 'le="100"' | awk -F' ' '{print $2}' | head -1)
    
    echo "  发布延迟分布:"
    echo "    ≤5ms: ${egress_p50:-0} 条"
    echo "    ≤50ms: ${egress_p95:-0} 条" 
    echo "    ≤100ms: ${egress_p99:-0} 条"
    
    # 接收指标 (Ingress)
    echo ""
    echo "📥 接收指标 (Ingress):"
    local ingress_count=$(echo "$metrics" | grep "dapr_component_pubsub_ingress_count" | grep -v "^#" | awk -F' ' '{print $2}' | head -1)
    echo "  总接收消息数: ${ingress_count:-0}"
    
    # 接收延迟统计
    local ingress_p50=$(echo "$metrics" | grep "dapr_component_pubsub_ingress_latencies" | grep 'le="5"' | awk -F' ' '{print $2}' | head -1)
    local ingress_p95=$(echo "$metrics" | grep "dapr_component_pubsub_ingress_latencies" | grep 'le="50"' | awk -F' ' '{print $2}' | head -1)
    local ingress_p99=$(echo "$metrics" | grep "dapr_component_pubsub_ingress_latencies" | grep 'le="100"' | awk -F' ' '{print $2}' | head -1)
    
    echo "  接收处理延迟分布:"
    echo "    ≤5ms: ${ingress_p50:-0} 条"
    echo "    ≤50ms: ${ingress_p95:-0} 条"
    echo "    ≤100ms: ${ingress_p99:-0} 条"
    
    # 计算消息积压（发布 vs 接收）
    if [ -n "$egress_count" ] && [ -n "$ingress_count" ] && [ "$egress_count" -gt 0 ] && [ "$ingress_count" -gt 0 ]; then
        local backlog=$((ingress_count - egress_count))
        echo ""
        echo "⚖️  消息流量分析:"
        echo "  发布总数: $egress_count"
        echo "  接收总数: $ingress_count"
        if [ "$backlog" -gt 0 ]; then
            echo "  ✅ 消费领先: +$backlog (接收多于发布)"
        elif [ "$backlog" -lt 0 ]; then
            echo "  ⚠️  潜在积压: $backlog (发布多于接收)"
        else
            echo "  ✅ 收发平衡"
        fi
    fi
    
    # HTTP 服务器指标
    echo ""
    echo "🌐 HTTP 服务器指标:"
    local http_requests=$(echo "$metrics" | grep "dapr_http_server_request_count" | grep -v "^#" | awk -F' ' '{print $2}' | head -1)
    local http_latency_p95=$(echo "$metrics" | grep "dapr_http_server_latency" | grep 'le="50"' | awk -F' ' '{print $2}' | head -1)
    
    echo "  HTTP 请求总数: ${http_requests:-0}"
    echo "  ≤50ms 响应数: ${http_latency_p95:-0}"
    
    echo ""
}

# 实时监控函数
realtime_metrics_monitor() {
    echo "🚀 实时指标监控"
    echo "Press Ctrl+C to stop"
    echo ""
    
    local pods=($(get_dapr_pods))
    local port=9090
    
    while true; do
        clear
        echo "🕐 $(date)"
        echo "====================================="
        
        for pod in "${pods[@]}"; do
            echo "📊 监控 Pod: $pod"
            
            # 快速指标获取（使用已有的端口转发）
            local metrics=$(get_metrics_from_pod $pod $port)
            
            if [ -n "$metrics" ]; then
                # 提取关键指标
                local egress=$(echo "$metrics" | grep "dapr_component_pubsub_egress_count" | grep -v "^#" | awk -F' ' '{print $2}' | head -1)
                local ingress=$(echo "$metrics" | grep "dapr_component_pubsub_ingress_count" | grep -v "^#" | awk -F' ' '{print $2}' | head -1)
                local http_reqs=$(echo "$metrics" | grep "dapr_http_server_request_count" | grep -v "^#" | awk -F' ' '{print $2}' | head -1)
                
                echo "  📤 发布: ${egress:-0}  📥 接收: ${ingress:-0}  🌐 HTTP: ${http_reqs:-0}"
                
                # 计算速率（简单估算）
                if [ -n "$egress" ] && [ -n "$ingress" ]; then
                    echo "  💱 发布/接收比: $(echo "scale=2; ${egress:-1} / ${ingress:-1}" | bc -l 2>/dev/null || echo "N/A")"
                fi
            else
                echo "  ❌ 无法获取指标"
            fi
            
            echo ""
            ((port++))  # 避免端口冲突
        done
        
        sleep 5
        port=9090  # 重置端口
    done
}

# 详细分析函数  
detailed_analysis() {
    local pods=($(get_dapr_pods))
    local port=9090
    
    echo "🔍 详细指标分析"
    echo "=================="
    
    for pod in "${pods[@]}"; do
        echo "正在分析 Pod: $pod..."
        local metrics=$(get_metrics_from_pod $pod $port)
        
        if [ -n "$metrics" ]; then
            parse_pubsub_metrics "$metrics" "$pod"
            echo "======================================"
        else
            echo "❌ 无法从 $pod 获取指标"
        fi
        
        ((port++))
        sleep 1
    done
}

# 性能基准测试
performance_benchmark() {
    echo "🏁 性能基准测试"
    echo "================"
    
    local pods=($(get_dapr_pods))
    echo "监控周期: 60秒"
    echo "开始时间: $(date)"
    
    # 获取初始指标
    echo "📊 收集初始指标..."
    declare -A start_egress
    declare -A start_ingress
    local port=9090
    
    for pod in "${pods[@]}"; do
        local metrics=$(get_metrics_from_pod $pod $port)
        start_egress[$pod]=$(echo "$metrics" | grep "dapr_component_pubsub_egress_count" | grep -v "^#" | awk -F' ' '{print $2}' | head -1)
        start_ingress[$pod]=$(echo "$metrics" | grep "dapr_component_pubsub_ingress_count" | grep -v "^#" | awk -F' ' '{print $2}' | head -1)
        ((port++))
    done
    
    echo "⏳ 等待 60 秒..."
    sleep 60
    
    # 获取结束指标
    echo "📊 收集结束指标..."
    port=9090
    for pod in "${pods[@]}"; do
        local metrics=$(get_metrics_from_pod $pod $port)
        local end_egress=$(echo "$metrics" | grep "dapr_component_pubsub_egress_count" | grep -v "^#" | awk -F' ' '{print $2}' | head -1)
        local end_ingress=$(echo "$metrics" | grep "dapr_component_pubsub_ingress_count" | grep -v "^#" | awk -F' ' '{print $2}' | head -1)
        
        echo ""
        echo "📱 Pod: $pod"
        echo "  发布速率: $(((${end_egress:-0} - ${start_egress[$pod]:-0}) / 60)) 消息/秒"
        echo "  接收速率: $(((${end_ingress:-0} - ${start_ingress[$pod]:-0}) / 60)) 消息/秒"
        
        ((port++))
    done
    
    echo ""
    echo "结束时间: $(date)"
}

# 主菜单
pods=($(get_dapr_pods))
if [ ${#pods[@]} -eq 0 ]; then
    echo "❌ 没有找到启用了 Dapr 的 Pods"
    exit 1
fi

echo "找到 ${#pods[@]} 个 Dapr-enabled Pods:"
for pod in "${pods[@]}"; do
    echo "  - $pod"
done
echo ""

echo "选择监控模式："
echo "1) 详细指标分析"
echo "2) 实时指标监控"
echo "3) 性能基准测试"
echo "4) 快速状态检查"
read -p "请选择 (1-4): " choice

case $choice in
    1)
        detailed_analysis
        ;;
    2)
        realtime_metrics_monitor
        ;;
    3)
        performance_benchmark
        ;;
    4)
        echo "⚡ 快速状态检查"
        echo "================"
        detailed_analysis | grep -E "(Pod:|总发布消息数:|总接收消息数:|消息流量分析:|HTTP 请求总数:)" 
        ;;
esac

# 清理后台进程
pkill -f "kubectl port-forward" >/dev/null 2>&1 