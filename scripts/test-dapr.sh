#!/bin/bash

echo "🚀 Dapr Pub/Sub 测试脚本"
echo "========================"

# 检查Dapr是否安装
echo "1. 检查Dapr安装状态..."
if ! command -v dapr &> /dev/null; then
    echo "❌ Dapr CLI 未安装，请先安装 Dapr CLI"
    exit 1
fi

dapr_status=$(dapr status -k)
if echo "$dapr_status" | grep -q "False"; then
    echo "❌ Dapr 组件未正常运行，请检查安装"
    echo "$dapr_status"
    exit 1
fi

echo "✅ Dapr 安装正常"

# 检查Redis连接信息
echo ""
echo "2. 检查现有Redis服务..."
kubectl get svc | grep redis
if [ $? -ne 0 ]; then
    echo "⚠️  未找到Redis服务，请确认您的Redis服务名称"
    echo "   您可以手动修改 infrastructure/dapr/redis-pubsub.yaml 中的 redisHost 配置"
fi

# 部署Redis Pub/Sub组件
echo ""
echo "3. 部署Redis Pub/Sub组件..."
kubectl apply -f infrastructure/dapr/redis-pubsub.yaml

# 等待组件就绪
echo "   等待组件初始化..."
sleep 5

# 验证组件状态
kubectl get components
echo ""

# 部署测试应用
echo "4. 部署测试应用..."
echo "   部署生产者..."
kubectl apply -f infrastructure/dapr/test-producer.yaml

echo "   部署消费者..."
kubectl apply -f infrastructure/dapr/test-consumer.yaml

# 等待Pod启动
echo ""
echo "5. 等待Pod启动..."
sleep 10

# 检查Pod状态
echo "   检查Pod状态..."
kubectl get pods -l app=test-producer
kubectl get pods -l app=test-consumer

# 等待sidecar注入和启动
echo ""
echo "6. 等待Dapr sidecar启动 (30秒)..."
sleep 30

# 检查是否有两个容器
echo ""
echo "7. 验证sidecar注入..."
producer_containers=$(kubectl get pod -l app=test-producer -o jsonpath='{.items[0].spec.containers[*].name}')
consumer_containers=$(kubectl get pod -l app=test-consumer -o jsonpath='{.items[0].spec.containers[*].name}')

echo "   生产者容器: $producer_containers"
echo "   消费者容器: $consumer_containers"

if [[ "$producer_containers" == *"daprd"* ]] && [[ "$consumer_containers" == *"daprd"* ]]; then
    echo "✅ Sidecar注入成功"
else
    echo "❌ Sidecar注入失败，请检查Dapr配置"
    exit 1
fi

# 查看日志
echo ""
echo "8. 查看应用日志 (Ctrl+C退出)..."
echo "========================"
echo "生产者日志:"
kubectl logs -l app=test-producer -c producer --tail=5
echo ""
echo "消费者日志:"
kubectl logs -l app=test-consumer -c consumer --tail=5

echo ""
echo "========================"
echo "🎉 Dapr测试应用部署完成！"
echo ""
echo "查看实时日志命令:"
echo "  生产者: kubectl logs -l app=test-producer -c producer -f"
echo "  消费者: kubectl logs -l app=test-consumer -c consumer -f"
echo "  Sidecar: kubectl logs -l app=test-producer -c daprd -f"
echo ""
echo "手动发送测试消息:"
echo "  kubectl exec deployment/dapr-test-producer -c producer -- \\"
echo "    curl -X POST http://localhost:3500/v1.0/publish/pubsub/pod-events \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"message\": \"Manual test\", \"timestamp\": \"$(date)\"}'"
echo ""
echo "清理测试环境:"
echo "  kubectl delete -f infrastructure/dapr/"
echo ""
echo "访问Dapr Dashboard:"
echo "  kubectl port-forward svc/dapr-dashboard -n dapr-system 8080:8080"
echo "  然后访问: http://localhost:8080" 