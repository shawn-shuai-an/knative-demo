#!/bin/bash

# Redis 连接配置 - 请根据您的实际配置修改
REDIS_HOST="172.22.131.59"
REDIS_PORT="6379"
REDIS_DB="2"

echo "🔍 Redis Stream 监控工具"
echo "=========================="

# 检查 Redis 连接
echo "📡 Testing Redis connection..."
if ! redis-cli -h $REDIS_HOST -p $REDIS_PORT -n $REDIS_DB ping > /dev/null 2>&1; then
    echo "❌ Cannot connect to Redis at $REDIS_HOST:$REDIS_PORT"
    echo "Please install redis-cli: brew install redis (macOS) or apt-get install redis-tools (Ubuntu)"
    exit 1
fi
echo "✅ Redis connection OK"
echo ""

# 显示所有 Streams
echo "📋 Available Streams:"
streams=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT -n $REDIS_DB --scan --pattern "*" --type stream)
if [ -z "$streams" ]; then
    echo "❌ No streams found"
    exit 0
fi

for stream in $streams; do
    echo "  - $stream"
done
echo ""

# 监控主函数
monitor_stream() {
    local stream_name=$1
    echo "🔍 Monitoring Stream: $stream_name"
    echo "===================="
    
    # Stream 基本信息
    echo "📊 Stream Info:"
    redis-cli -h $REDIS_HOST -p $REDIS_PORT -n $REDIS_DB XINFO STREAM "$stream_name"
    echo ""
    
    # Consumer Groups 信息
    echo "👥 Consumer Groups:"
    redis-cli -h $REDIS_HOST -p $REDIS_PORT -n $REDIS_DB XINFO GROUPS "$stream_name" 2>/dev/null || echo "No consumer groups found"
    echo ""
    
    # 显示最近的消息
    echo "📨 Recent Messages (last 5):"
    redis-cli -h $REDIS_HOST -p $REDIS_PORT -n $REDIS_DB XREVRANGE "$stream_name" + - COUNT 5
    echo ""
    
    # Consumer Groups 详细信息
    echo "📈 Consumer Group Details:"
    groups=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT -n $REDIS_DB XINFO GROUPS "$stream_name" 2>/dev/null | grep -o 'name [^ ]*' | cut -d' ' -f2)
    
    for group in $groups; do
        echo "  Group: $group"
        redis-cli -h $REDIS_HOST -p $REDIS_PORT -n $REDIS_DB XINFO CONSUMERS "$stream_name" "$group" 2>/dev/null || echo "    No consumers"
        echo ""
    done
}

# 实时监控函数
realtime_monitor() {
    local stream_name=$1
    echo "🚀 Real-time monitoring for: $stream_name"
    echo "Press Ctrl+C to stop"
    echo ""
    
    while true; do
        clear
        echo "🕐 $(date)"
        echo "===================="
        
        # Stream 长度
        length=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT -n $REDIS_DB XLEN "$stream_name")
        echo "📏 Stream Length: $length messages"
        
        # 获取 consumer groups 的 lag
        groups=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT -n $REDIS_DB XINFO GROUPS "$stream_name" 2>/dev/null | grep -o 'lag [0-9]*' | cut -d' ' -f2)
        
        if [ -n "$groups" ]; then
            echo "🔄 Consumer Group Lag:"
            i=1
            for lag in $groups; do
                echo "  Group $i: $lag pending messages"
                ((i++))
            done
        fi
        
        # 最新消息
        echo ""
        echo "📨 Latest Message:"
        redis-cli -h $REDIS_HOST -p $REDIS_PORT -n $REDIS_DB XREVRANGE "$stream_name" + - COUNT 1
        
        sleep 2
    done
}

# 主菜单
echo "选择监控模式："
echo "1) 查看所有 Streams 概况"
echo "2) 监控特定 Stream"
echo "3) 实时监控特定 Stream"
echo "4) 查看消费者性能统计"
read -p "请选择 (1-4): " choice

case $choice in
    1)
        for stream in $streams; do
            monitor_stream "$stream"
            echo "======================================"
        done
        ;;
    2)
        echo "Available streams:"
        i=1
        stream_array=()
        for stream in $streams; do
            echo "$i) $stream"
            stream_array[$i]=$stream
            ((i++))
        done
        read -p "选择要监控的 Stream (1-$((i-1))): " stream_choice
        monitor_stream "${stream_array[$stream_choice]}"
        ;;
    3)
        echo "Available streams:"
        i=1
        stream_array=()
        for stream in $streams; do
            echo "$i) $stream"
            stream_array[$i]=$stream
            ((i++))
        done
        read -p "选择要实时监控的 Stream (1-$((i-1))): " stream_choice
        realtime_monitor "${stream_array[$stream_choice]}"
        ;;
    4)
        echo "📊 消费者性能统计"
        echo "==================="
        for stream in $streams; do
            echo "Stream: $stream"
            echo "  Length: $(redis-cli -h $REDIS_HOST -p $REDIS_PORT -n $REDIS_DB XLEN "$stream") messages"
            
            # 计算消息生产速度（过去5分钟）
            now=$(date +%s)
            five_min_ago=$((now * 1000 - 300000))  # 5分钟前的毫秒时间戳
            recent_count=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT -n $REDIS_DB XRANGE "$stream" "$five_min_ago" + | wc -l)
            recent_rate=$(echo "scale=2; $recent_count / 5" | bc -l 2>/dev/null || echo "需要安装bc命令")
            echo "  Recent rate: $recent_rate messages/minute"
            echo ""
        done
        ;;
esac 