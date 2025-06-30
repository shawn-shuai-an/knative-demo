#!/bin/bash

# 快速监控 Dapr + Redis 的简单命令
NAMESPACE="dapr-demo"
REDIS_HOST="172.22.131.59"
REDIS_PORT="6379" 
REDIS_DB="2"

echo "⚡ 快速监控面板"
echo "==============="

# 1. 基本状态检查
echo "🔍 1. 基本状态检查"
echo "Pod 状态:"
kubectl get pods -n $NAMESPACE -o wide

echo ""
echo "Dapr 组件:"
kubectl get components -n $NAMESPACE

echo ""

# 2. 消息流统计
echo "📊 2. 消息流统计 (最近1分钟日志)"
for pod in $(kubectl get pods -n $NAMESPACE -l dapr.io/enabled=true -o name); do
    pod_name=$(echo $pod | cut -d'/' -f2)
    echo "Pod: $pod_name"
    
    # 发布统计
    published=$(kubectl logs $pod_name -n $NAMESPACE -c app --since=1m 2>/dev/null | grep -c "Published message" || echo "0")
    echo "  📤 发布: $published 条"
    
    # 接收统计  
    received=$(kubectl logs $pod_name -n $NAMESPACE -c app --since=1m 2>/dev/null | grep -c "Received event" || echo "0")
    echo "  📥 接收: $received 条"
    
    # 错误统计
    errors=$(kubectl logs $pod_name -n $NAMESPACE -c daprd --since=1m 2>/dev/null | grep -ci error || echo "0")
    if [ "$errors" -gt 0 ]; then
        echo "  ❌ 错误: $errors 个"
    else
        echo "  ✅ 无错误"
    fi
    echo ""
done

# 3. Redis Stream 快速检查
echo "🗄️  3. Redis Stream 状态"
if command -v redis-cli >/dev/null 2>&1; then
    streams=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT -n $REDIS_DB --scan --pattern "*" --type stream 2>/dev/null)
    if [ -n "$streams" ]; then
        for stream in $streams; do
            length=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT -n $REDIS_DB XLEN "$stream" 2>/dev/null || echo "N/A")
            echo "Stream: $stream - 长度: $length"
            
            # Consumer group lag
            groups=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT -n $REDIS_DB XINFO GROUPS "$stream" 2>/dev/null | grep -o 'lag [0-9]*' | cut -d' ' -f2)
            if [ -n "$groups" ]; then
                i=1
                for lag in $groups; do
                    echo "  Consumer Group $i lag: $lag"
                    ((i++))
                done
            fi
        done
    else
        echo "未找到 Redis Streams"
    fi
else
    echo "未安装 redis-cli，跳过 Redis 检查"
    echo "安装命令: brew install redis (macOS) 或 apt-get install redis-tools (Ubuntu)"
fi

echo ""

# 4. 网络连接检查
echo "🌐 4. 网络连接检查"
for pod in $(kubectl get pods -n $NAMESPACE -l dapr.io/enabled=true -o name); do
    pod_name=$(echo $pod | cut -d'/' -f2)
    echo "Pod: $pod_name"
    
    # Redis 连接
    if kubectl exec $pod_name -n $NAMESPACE -c app -- nc -zv $REDIS_HOST $REDIS_PORT >/dev/null 2>&1; then
        echo "  ✅ Redis 连接正常"
    else
        echo "  ❌ Redis 连接失败"
    fi
    
    # Dapr sidecar 连接
    if kubectl exec $pod_name -n $NAMESPACE -c app -- nc -zv localhost 3500 >/dev/null 2>&1; then
        echo "  ✅ Dapr sidecar 连接正常"
    else
        echo "  ❌ Dapr sidecar 连接失败"
    fi
    echo ""
done

# 5. 最近错误
echo "⚠️  5. 最近错误 (最近5分钟)"
has_errors=false
for pod in $(kubectl get pods -n $NAMESPACE -l dapr.io/enabled=true -o name); do
    pod_name=$(echo $pod | cut -d'/' -f2)
    errors=$(kubectl logs $pod_name -n $NAMESPACE -c daprd --since=5m 2>/dev/null | grep -i error)
    if [ -n "$errors" ]; then
        echo "Pod: $pod_name"
        echo "$errors" | tail -3
        echo ""
        has_errors=true
    fi
done

if [ "$has_errors" = false ]; then
    echo "✅ 最近5分钟内无错误"
fi

echo ""
echo "🕐 监控时间: $(date)"
echo "===============" 