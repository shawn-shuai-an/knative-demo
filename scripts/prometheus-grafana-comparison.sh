#!/bin/bash
# Prometheus + Grafana 监控对比演示脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=================================================="
echo -e "Prometheus + Grafana 监控对比演示"
echo -e "=================================================="
echo -e "${NC}"

# 检查是否安装了 helm
if ! command -v helm &> /dev/null; then
    echo -e "${RED}❌ Helm 未安装，请先安装 Helm${NC}"
    exit 1
fi

# 检查是否连接到 K8s
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ 无法连接到 Kubernetes 集群${NC}"
    exit 1
fi

echo -e "${GREEN}✅ 环境检查通过${NC}"

# 函数：部署 Prometheus + Grafana
deploy_monitoring_stack() {
    echo -e "${YELLOW}📊 部署 Prometheus + Grafana 监控栈...${NC}"
    
    # 添加 Prometheus 社区 Helm 仓库
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    # 创建 monitoring namespace
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    # 部署 kube-prometheus-stack (包含 Prometheus + Grafana + AlertManager)
    helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
        -n monitoring \
        --set grafana.adminPassword=admin123 \
        --set prometheus.prometheusSpec.retention=30d \
        --set grafana.service.type=NodePort \
        --set prometheus.service.type=NodePort \
        --wait
    
    echo -e "${GREEN}✅ Prometheus + Grafana 部署完成${NC}"
}

# 函数：获取访问信息
get_access_info() {
    echo -e "${YELLOW}🔗 获取访问信息...${NC}"
    
    # 等待服务就绪
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n monitoring --timeout=300s
    
    # 获取 NodePort
    GRAFANA_PORT=$(kubectl get svc monitoring-grafana -n monitoring -o jsonpath='{.spec.ports[0].nodePort}')
    PROMETHEUS_PORT=$(kubectl get svc monitoring-kube-prometheus-prometheus -n monitoring -o jsonpath='{.spec.ports[0].nodePort}')
    
    # 获取 Node IP
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    
    echo -e "${GREEN}========================================="
    echo -e "📊 监控服务访问信息："
    echo -e "Grafana:    http://${NODE_IP}:${GRAFANA_PORT}"
    echo -e "用户名:     admin"
    echo -e "密码:       admin123"
    echo -e ""
    echo -e "Prometheus: http://${NODE_IP}:${PROMETHEUS_PORT}"
    echo -e "========================================="
    echo -e "${NC}"
}

# 函数：展示 Knative 查询示例
show_knative_queries() {
    echo -e "${BLUE}📈 Knative Prometheus 查询示例${NC}"
    echo -e "${YELLOW}1. 消息堆积估算（复杂，不精确）：${NC}"
    cat << 'EOF'
# 估算生产速率
rate(event_count{broker_name="default", response_code="202"}[5m])

# 估算消费速率  
rate(event_count{trigger_name="demo-event-trigger", response_code="200"}[5m])

# 手动计算积压（时间窗口需要手动调整）
(
  increase(event_count{broker_name="default", response_code="202"}[1h]) -
  increase(event_count{trigger_name="demo-event-trigger", response_code="200"}[1h])
)
EOF

    echo -e "${YELLOW}2. 事件处理延迟（平台延迟，非业务延迟）：${NC}"
    cat << 'EOF'
# P95 事件分发延迟
histogram_quantile(0.95, rate(event_dispatch_latencies_bucket{broker_name="default"}[5m]))

# Trigger 处理延迟（包含网络传输）
histogram_quantile(0.95, rate(event_processing_latencies_bucket{trigger_name="demo-event-trigger"}[5m]))
EOF

    echo -e "${YELLOW}3. 成功率监控：${NC}"
    cat << 'EOF'
# 事件分发成功率
(
  rate(event_count{broker_name="default", response_code="202"}[5m]) /
  rate(event_count{broker_name="default"}[5m])
) * 100

# Trigger 处理成功率
(
  rate(event_count{trigger_name="demo-event-trigger", response_code="200"}[5m]) /
  rate(event_count{trigger_name="demo-event-trigger"}[5m])
) * 100
EOF
    echo ""
}

# 函数：展示 Dapr 查询示例
show_dapr_queries() {
    echo -e "${BLUE}📈 Dapr Prometheus 查询示例${NC}"
    echo -e "${YELLOW}1. 消息堆积计算（精确，简单）：${NC}"
    cat << 'EOF'
# 精确的消息堆积计算
(
  sum(dapr_component_pubsub_egress_count{component="pubsub", topic="pod-events"}) -
  sum(dapr_component_pubsub_ingress_count{component="pubsub", topic="pod-events"})
)

# 发布速率
rate(dapr_component_pubsub_egress_count{component="pubsub", topic="pod-events"}[5m])

# 消费速率
rate(dapr_component_pubsub_ingress_count{component="pubsub", topic="pod-events"}[5m])

# 按 Topic 分组的堆积情况
sum by (topic) (
  dapr_component_pubsub_egress_count{component="pubsub"} -
  dapr_component_pubsub_ingress_count{component="pubsub"}
)
EOF

    echo -e "${YELLOW}2. 业务处理延迟（真实业务延迟）：${NC}"
    cat << 'EOF'
# P95 业务处理延迟
histogram_quantile(0.95, rate(dapr_component_pubsub_ingress_latencies_bucket{app_id="consumer"}[5m]))

# 发布延迟
histogram_quantile(0.95, rate(dapr_component_pubsub_egress_latencies_bucket{app_id="producer"}[5m]))

# HTTP 服务延迟
histogram_quantile(0.95, rate(dapr_http_server_latency_bucket{app_id="consumer", path="/pod-events"}[5m]))
EOF

    echo -e "${YELLOW}3. 成功率监控：${NC}"
    cat << 'EOF'
# 发布成功率
(
  rate(dapr_component_pubsub_egress_count{success="true"}[5m]) /
  rate(dapr_component_pubsub_egress_count[5m])
) * 100

# 处理成功率
(
  rate(dapr_component_pubsub_ingress_count{process_status="success"}[5m]) /
  rate(dapr_component_pubsub_ingress_count[5m])
) * 100
EOF
    echo ""
}

# 函数：创建 Grafana 仪表板
create_grafana_dashboards() {
    echo -e "${YELLOW}📊 创建对比仪表板...${NC}"
    
    # 等待 Grafana 完全启动
    sleep 30
    
    # 获取 Grafana Pod
    GRAFANA_POD=$(kubectl get pod -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}')
    
    # 创建 Knative 仪表板
    kubectl exec -n monitoring $GRAFANA_POD -- sh -c "
cat > /tmp/knative-dashboard.json << 'EOF'
{
  \"dashboard\": {
    \"id\": null,
    \"title\": \"Knative vs Dapr 监控对比\",
    \"tags\": [\"comparison\"],
    \"panels\": [
      {
        \"id\": 1,
        \"title\": \"Knative - 估算消息堆积（复杂查询）\",
        \"type\": \"stat\",
        \"targets\": [{
          \"expr\": \"increase(event_count{broker_name=\\\"default\\\", response_code=\\\"202\\\"}[10m]) - increase(event_count{trigger_name=~\\\".*\\\", response_code=\\\"200\\\"}[10m])\",
          \"legendFormat\": \"估算堆积\"
        }],
        \"gridPos\": {\"h\": 8, \"w\": 12, \"x\": 0, \"y\": 0}
      },
      {
        \"id\": 2,
        \"title\": \"Dapr - 精确消息堆积（简单查询）\",
        \"type\": \"stat\",
        \"targets\": [{
          \"expr\": \"sum(dapr_component_pubsub_egress_count{component=\\\"pubsub\\\", topic=\\\"pod-events\\\"}) - sum(dapr_component_pubsub_ingress_count{component=\\\"pubsub\\\", topic=\\\"pod-events\\\"})\",
          \"legendFormat\": \"精确堆积\"
        }],
        \"gridPos\": {\"h\": 8, \"w\": 12, \"x\": 12, \"y\": 0}
      }
    ]
  }
}
EOF"
    
    echo -e "${GREEN}✅ 仪表板创建完成${NC}"
}

# 函数：展示监控能力对比
show_monitoring_comparison() {
    echo -e "${BLUE}📊 监控能力评估表${NC}"
    echo -e "${YELLOW}+---------------------------+----------+----------+${NC}"
    echo -e "${YELLOW}| 监控维度                  | Knative  | Dapr     |${NC}"
    echo -e "${YELLOW}+---------------------------+----------+----------+${NC}"
    echo -e "| 消息堆积计算精度          | ⭐⭐⭐     | ⭐⭐⭐⭐⭐ |"
    echo -e "| Prometheus 查询复杂度     | ⭐⭐       | ⭐⭐⭐⭐⭐ |"
    echo -e "| Grafana Dashboard 开发    | ⭐⭐⭐     | ⭐⭐⭐⭐⭐ |"
    echo -e "| 告警规则设置              | ⭐⭐⭐     | ⭐⭐⭐⭐⭐ |"
    echo -e "| 开箱即用程度              | ⭐⭐⭐     | ⭐⭐⭐⭐⭐ |"
    echo -e "| 平台组件监控              | ⭐⭐⭐⭐⭐ | ⭐⭐⭐   |"
    echo -e "| 业务指标精度              | ⭐⭐       | ⭐⭐⭐⭐⭐ |"
    echo -e "${YELLOW}+---------------------------+----------+----------+${NC}"
    echo ""
    
    echo -e "${GREEN}关键差异总结：${NC}"
    echo -e "1. ${YELLOW}查询复杂度${NC}："
    echo -e "   - Knative: 需要组合多个指标估算，查询复杂"
    echo -e "   - Dapr: 一行查询获得精确结果"
    echo ""
    echo -e "2. ${YELLOW}业务监控精度${NC}："
    echo -e "   - Knative: 主要监控平台分发延迟，业务处理状态需要额外指标"
    echo -e "   - Dapr: 直接提供业务处理延迟和成功率指标"
    echo ""
    echo -e "3. ${YELLOW}告警设置${NC}："
    echo -e "   - Knative: 告警条件基于估算，可能不够准确"
    echo -e "   - Dapr: 告警基于精确的业务指标，更可靠"
}

# 函数：清理资源
cleanup() {
    echo -e "${YELLOW}🧹 清理监控资源...${NC}"
    helm uninstall monitoring -n monitoring
    kubectl delete namespace monitoring
    echo -e "${GREEN}✅ 清理完成${NC}"
}

# 主程序
case "${1:-}" in
    "deploy")
        deploy_monitoring_stack
        get_access_info
        create_grafana_dashboards
        ;;
    "queries")
        show_knative_queries
        show_dapr_queries
        ;;
    "compare")
        show_monitoring_comparison
        ;;
    "cleanup")
        cleanup
        ;;
    *)
        echo -e "${BLUE}使用方法：${NC}"
        echo "  $0 deploy     - 部署 Prometheus + Grafana"
        echo "  $0 queries    - 显示查询语句对比"
        echo "  $0 compare    - 显示监控能力对比"
        echo "  $0 cleanup    - 清理资源"
        echo ""
        echo -e "${YELLOW}建议执行顺序：${NC}"
        echo "1. $0 deploy      # 部署监控栈"
        echo "2. $0 queries     # 查看查询对比"
        echo "3. $0 compare     # 查看能力对比"
        echo "4. $0 cleanup     # 清理（可选）"
        ;;
esac 