#!/bin/bash

echo "🧹 Cleaning up Dapr demo resources..."

# 删除测试部署
echo "Deleting test deployments..."
kubectl delete deployment dapr-simple-test -n dapr-demo --ignore-not-found=true
kubectl delete deployment dapr-simple-test-fixed -n dapr-demo --ignore-not-found=true
kubectl delete deployment dapr-test-producer -n dapr-demo --ignore-not-found=true
kubectl delete deployment dapr-test-consumer -n dapr-demo --ignore-not-found=true

# 删除服务
echo "Deleting services..."
kubectl delete service simple-test-service -n dapr-demo --ignore-not-found=true
kubectl delete service simple-test-fixed-service -n dapr-demo --ignore-not-found=true
kubectl delete service test-consumer-service -n dapr-demo --ignore-not-found=true
kubectl delete service test-producer-service -n dapr-demo --ignore-not-found=true

# 删除Dapr组件
echo "Deleting Dapr components..."
kubectl delete component pubsub -n dapr-demo --ignore-not-found=true

# 可选：删除整个namespace（注意：这会删除Dapr系统组件）
read -p "🚨 Do you want to delete the entire dapr-demo namespace? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Deleting dapr-demo namespace..."
    kubectl delete namespace dapr-demo
    echo "✅ Namespace deleted"
else
    echo "✅ Namespace preserved"
fi

echo "🎉 Cleanup completed!"

# 显示剩余资源
echo "📋 Remaining resources in dapr-demo namespace:"
kubectl get all -n dapr-demo 