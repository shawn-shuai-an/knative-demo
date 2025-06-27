#!/bin/bash

# Knative Demo 环境清理脚本

set -e

echo "🧹 开始清理 Knative Demo 基础设施..."

# 检查命名空间是否存在
if ! kubectl get namespace knative-demo &> /dev/null; then
    echo "ℹ️  命名空间 knative-demo 不存在，无需清理"
    exit 0
fi

# 删除 Trigger
echo "🎯 删除 Trigger..."
kubectl delete -f knative/trigger.yaml --ignore-not-found=true

# 删除 Knative 服务
echo "🛠️  删除 Knative 服务..."
kubectl delete -f knative/services.yaml --ignore-not-found=true

# 删除应用配置 ConfigMap
echo "🗂️  删除应用配置..."
kubectl delete -f kubernetes/producer-configmap.yaml --ignore-not-found=true
kubectl delete -f kubernetes/consumer-configmap.yaml --ignore-not-found=true

# 删除 Broker
echo "🔗 删除 Broker..."
kubectl delete -f knative/broker.yaml --ignore-not-found=true

# 删除命名空间（这会删除所有相关资源）
echo "📦 删除命名空间..."
kubectl delete -f knative/namespace.yaml --ignore-not-found=true

# 等待命名空间完全删除
echo "⏱️  等待命名空间完全删除..."
kubectl wait --for=delete namespace/knative-demo --timeout=60s || true

echo ""
echo "✅ Knative Demo 基础设施清理完成！"
echo ""
echo "🔍 验证清理结果:"
if kubectl get namespace knative-demo &> /dev/null; then
    echo "⚠️  命名空间仍存在，可能需要更多时间完成清理"
else
    echo "✅ 命名空间已成功删除"
fi 