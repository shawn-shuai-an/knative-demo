#!/bin/bash

# Knative Demo 一键迁移到 Kafka 脚本

set -e

echo "🚀 开始迁移 Knative Demo 到 Kafka..."

# 检查 Helm 是否可用
if ! command -v helm &> /dev/null; then
    echo "❌ Helm 未找到，请先安装 Helm"
    exit 1
fi

# 步骤1: 安装 Kafka 集群
echo "📦 安装 Kafka 集群..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# 检查是否已经安装了 Kafka
if helm list | grep -q kafka; then
    echo "✅ Kafka 已安装，跳过安装步骤"
else
    echo "🔨 安装 Kafka (这可能需要几分钟)..."
    helm install kafka bitnami/kafka \
        --set replicaCount=3 \
        --set persistence.enabled=true \
        --set persistence.size=10Gi \
        --set zookeeper.persistence.enabled=true \
        --set zookeeper.persistence.size=5Gi \
        --wait --timeout=600s
fi

# 步骤2: 等待 Kafka 就绪
echo "⏱️  等待 Kafka 集群就绪..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=kafka --timeout=300s
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=zookeeper --timeout=300s

# 步骤3: 安装 Knative Kafka 扩展
echo "🔗 安装 Knative Kafka 扩展..."
kubectl apply -f https://github.com/knative-extensions/eventing-kafka-broker/releases/latest/download/eventing-kafka-controller.yaml
kubectl apply -f https://github.com/knative-extensions/eventing-kafka-broker/releases/latest/download/eventing-kafka-broker.yaml

# 等待 Kafka 控制器就绪
echo "⏱️  等待 Kafka 控制器就绪..."
kubectl wait --for=condition=Available deployment/kafka-controller -n knative-eventing --timeout=120s
kubectl wait --for=condition=Available deployment/kafka-broker-dispatcher -n knative-eventing --timeout=120s
kubectl wait --for=condition=Available deployment/kafka-broker-receiver -n knative-eventing --timeout=120s

# 步骤4: 创建 Kafka Broker 配置
echo "⚙️  创建 Kafka Broker 配置..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: kafka-broker-config
  namespace: knative-eventing
data:
  bootstrap.servers: "kafka.default.svc.cluster.local:9092"
  default.topic.partitions: "10"
  default.topic.replication.factor: "3"
  default.topic.retention.ms: "604800000"
EOF

# 步骤5: 修改现有 Broker 为 Kafka 类型 (零停机迁移)
echo "🔄 升级现有 Broker 到 Kafka..."
kubectl patch broker default -n knative-demo \
    --type='merge' \
    -p='{
        "metadata": {
            "annotations": {
                "eventing.knative.dev/broker.class": "Kafka"
            }
        },
        "spec": {
            "config": {
                "apiVersion": "v1",
                "kind": "ConfigMap", 
                "name": "kafka-broker-config",
                "namespace": "knative-eventing"
            }
        }
    }'

# 步骤6: 等待 Broker 重新配置
echo "⏱️  等待 Broker 重新配置..."
kubectl wait --for=condition=Ready broker/default -n knative-demo --timeout=120s

# 步骤7: 验证迁移结果
echo "🔍 验证迁移结果..."

echo "📊 Broker 状态:"
kubectl get broker default -n knative-demo -o jsonpath='{.metadata.annotations.eventing\.knative\.dev/broker\.class}'
echo ""

echo "📊 Trigger 状态:"
kubectl get trigger -n knative-demo

echo "📊 Kafka Topic (需要等待事件产生):"
echo "执行以下命令查看 Kafka Topic:"
echo "kubectl exec -it kafka-0 -- kafka-topics.sh --bootstrap-server localhost:9092 --list"

# 步骤8: 测试事件流
echo "🧪 测试事件流..."
echo "等待 30 秒观察事件流..."
timeout 30s kubectl logs -f deployment/event-consumer -n knative-demo || true

echo ""
echo "🎉 迁移完成！"
echo ""
echo "✅ 迁移结果:"
echo "  - Kafka 集群已部署并运行"
echo "  - Broker 已升级为 Kafka 类型"  
echo "  - Trigger 配置保持不变"
echo "  - 事件流已迁移到 Kafka 持久化存储"
echo ""
echo "📋 验证命令:"
echo "  # 查看 Kafka Topic:"
echo "  kubectl exec -it kafka-0 -- kafka-topics.sh --bootstrap-server localhost:9092 --list"
echo ""
echo "  # 查看 Producer 日志:"
echo "  kubectl logs -f deployment/event-producer -n knative-demo"
echo ""  
echo "  # 查看 Consumer 日志:"
echo "  kubectl logs -f deployment/event-consumer -n knative-demo"
echo ""
echo "🎯 现在你的 Demo 拥有了 Kafka 的持久化能力！" 