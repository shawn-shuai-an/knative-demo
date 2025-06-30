#!/bin/bash

echo "🧹 清理Dapr测试环境"
echo "=================="

# 删除测试应用
echo "1. 删除测试应用..."
kubectl delete -f infrastructure/dapr/test-producer.yaml --ignore-not-found=true
kubectl delete -f infrastructure/dapr/test-consumer.yaml --ignore-not-found=true

# 删除Pub/Sub组件
echo "2. 删除Pub/Sub组件..."
kubectl delete -f infrastructure/dapr/redis-pubsub.yaml --ignore-not-found=true

# 等待Pod终止
echo "3. 等待Pod终止..."
sleep 10

# 检查清理结果
echo "4. 检查清理结果..."
remaining_pods=$(kubectl get pods -l app=test-producer,app=test-consumer --no-headers 2>/dev/null | wc -l)
remaining_components=$(kubectl get components --no-headers 2>/dev/null | wc -l)

if [ "$remaining_pods" -eq 0 ]; then
    echo "✅ 测试Pod已清理完成"
else
    echo "⚠️  仍有 $remaining_pods 个Pod在运行，请手动检查"
    kubectl get pods -l "app in (test-producer,test-consumer)"
fi

if [ "$remaining_components" -eq 0 ]; then
    echo "✅ Dapr组件已清理完成"
else
    echo "⚠️  仍有 $remaining_components 个组件，请手动检查"
    kubectl get components
fi

echo ""
echo "🎉 清理完成！"
echo ""
echo "如果需要完全卸载Dapr，请运行:"
echo "  dapr uninstall -k" 