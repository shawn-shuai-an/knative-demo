# Prometheus + Grafana 监控对比：Knative vs Dapr

## 🎯 标准监控栈对比

在生产环境中，通常使用 **Prometheus + Grafana** 作为标准监控栈。让我们对比两者在这个环境下的监控能力。

## 📊 Prometheus 指标对比

### **Knative Eventing 指标**

#### **1. Broker 相关指标**
```prometheus
# Broker Ingress - 事件接收
event_count{broker_name="default", event_type="demo.event", namespace_name="knative-demo", response_code="202"}

# Broker Filter - 事件过滤和分发
event_count{broker_name="default", trigger_name="demo-event-trigger", namespace_name="knative-demo", response_code="200"}
event_processing_latencies{broker_name="default", trigger_name="demo-event-trigger", namespace_name="knative-demo"}

# Event dispatch latencies - 事件分发延迟
event_dispatch_latencies_bucket{broker_name="default", event_type="demo.event", le="50"}
```

#### **2. Event Source 指标**
```prometheus
# 事件源发送统计
event_count{event_source="event-producer", event_type="demo.event", namespace_name="knative-demo"}
retry_event_count{event_source="event-producer", event_type="demo.event", namespace_name="knative-demo"}
```

#### **3. Channel 指标**
```prometheus
# In-Memory Channel 分发
event_count{container_name="imc-dispatcher", event_type="demo.event", response_code="200"}
event_dispatch_latencies{container_name="imc-dispatcher", event_type="demo.event"}
```

### **Dapr 指标**

#### **1. Pub/Sub 组件指标**
```prometheus
# 消息发布指标
dapr_component_pubsub_egress_count{app_id="producer", component="pubsub", topic="pod-events", success="true"}
dapr_component_pubsub_egress_latencies_bucket{app_id="producer", component="pubsub", topic="pod-events", le="5"}

# 消息接收指标
dapr_component_pubsub_ingress_count{app_id="consumer", component="pubsub", topic="pod-events", process_status="success"}
dapr_component_pubsub_ingress_latencies_bucket{app_id="consumer", component="pubsub", topic="pod-events", le="50"}
```

#### **2. HTTP 服务器指标**
```prometheus
# HTTP 请求统计
dapr_http_server_request_count{app_id="consumer", method="POST", path="/pod-events", status_code="200"}
dapr_http_server_latency_bucket{app_id="consumer", method="POST", path="/pod-events", le="100"}
```

#### **3. Runtime 指标**
```prometheus
# Dapr Runtime 性能
dapr_runtime_component_init_total{component_type="pubsub", namespace="dapr-demo"}
dapr_grpc_io_client_completed_rpcs{app_id="consumer", grpc_method="PublishEvent"}
```

## 📈 Prometheus 查询语句对比

### **消息堆积监控**

#### **Knative 实现（复杂）**
```prometheus
# 需要组合多个指标，且不够精确
# 1. 估算生产速率（基于 Broker 接收）
rate(event_count{broker_name="default", response_code="202"}[5m])

# 2. 估算消费速率（基于 Trigger 处理）
rate(event_count{trigger_name="demo-event-trigger", response_code="200"}[5m])

# 3. 手动计算积压（不够准确）
(
  increase(event_count{broker_name="default", response_code="202"}[1h]) -
  increase(event_count{trigger_name="demo-event-trigger", response_code="200"}[1h])
)
```

#### **Dapr 实现（简单）**
```prometheus
# 精确的消息堆积计算
(
  sum(dapr_component_pubsub_egress_count{component="pubsub", topic="pod-events"}) -
  sum(dapr_component_pubsub_ingress_count{component="pubsub", topic="pod-events"})
)

# 发布速率
rate(dapr_component_pubsub_egress_count{component="pubsub", topic="pod-events"}[5m])

# 消费速率
rate(dapr_component_pubsub_ingress_count{component="pubsub", topic="pod-events"}[5m])
```

### **处理延迟监控**

#### **Knative 延迟查询**
```prometheus
# 平台分发延迟（不是业务处理延迟）
histogram_quantile(0.95, rate(event_dispatch_latencies_bucket{broker_name="default"}[5m]))

# Trigger 处理延迟（包含网络传输）
histogram_quantile(0.95, rate(event_processing_latencies_bucket{trigger_name="demo-event-trigger"}[5m]))
```

#### **Dapr 延迟查询**
```prometheus
# 业务处理延迟（真实的应用处理时间）
histogram_quantile(0.95, rate(dapr_component_pubsub_ingress_latencies_bucket{app_id="consumer"}[5m]))

# 发布延迟
histogram_quantile(0.95, rate(dapr_component_pubsub_egress_latencies_bucket{app_id="producer"}[5m]))

# HTTP 服务延迟
histogram_quantile(0.95, rate(dapr_http_server_latency_bucket{app_id="consumer", path="/pod-events"}[5m]))
```

### **成功率监控**

#### **Knative 成功率**
```prometheus
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
```

#### **Dapr 成功率**
```prometheus
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
```

## 🎨 Grafana Dashboard 对比

### **Knative Dashboard 设计**

#### **面板1：平台健康状态**
```json
{
  "title": "Broker Performance",
  "targets": [
    {
      "expr": "rate(event_count{broker_name=\"default\", response_code=\"202\"}[5m])",
      "legendFormat": "Events Received/sec"
    },
    {
      "expr": "rate(event_count{broker_name=\"default\", response_code!=\"202\"}[5m])",
      "legendFormat": "Failed Events/sec"
    }
  ]
}
```

#### **面板2：Trigger 性能**
```json
{
  "title": "Trigger Processing",
  "targets": [
    {
      "expr": "rate(event_count{trigger_name=~\".*\", response_code=\"200\"}[5m])",
      "legendFormat": "{{trigger_name}} - Processed/sec"
    },
    {
      "expr": "histogram_quantile(0.95, rate(event_processing_latencies_bucket{trigger_name=~\".*\"}[5m]))",
      "legendFormat": "{{trigger_name}} - P95 Latency"
    }
  ]
}
```

#### **面板3：事件类型分布**
```json
{
  "title": "Event Type Distribution",
  "targets": [
    {
      "expr": "rate(event_count{event_type=~\".*\"}[5m])",
      "legendFormat": "{{event_type}}"
    }
  ]
}
```

### **Dapr Dashboard 设计**

#### **面板1：消息流量概览**
```json
{
  "title": "Message Throughput",
  "targets": [
    {
      "expr": "rate(dapr_component_pubsub_egress_count{component=\"pubsub\"}[5m])",
      "legendFormat": "{{app_id}} - Published/sec"
    },
    {
      "expr": "rate(dapr_component_pubsub_ingress_count{component=\"pubsub\"}[5m])",
      "legendFormat": "{{app_id}} - Consumed/sec"
    }
  ]
}
```

#### **面板2：消息堆积状态**
```json
{
  "title": "Message Backlog",
  "targets": [
    {
      "expr": "sum(dapr_component_pubsub_egress_count{component=\"pubsub\", topic=\"pod-events\"}) - sum(dapr_component_pubsub_ingress_count{component=\"pubsub\", topic=\"pod-events\"})",
      "legendFormat": "Backlog Count"
    }
  ],
  "thresholds": [
    {"value": 0, "color": "green"},
    {"value": 100, "color": "yellow"},
    {"value": 1000, "color": "red"}
  ]
}
```

#### **面板3：处理延迟分析**
```json
{
  "title": "Processing Latency",
  "targets": [
    {
      "expr": "histogram_quantile(0.50, rate(dapr_component_pubsub_ingress_latencies_bucket{app_id=\"consumer\"}[5m]))",
      "legendFormat": "P50"
    },
    {
      "expr": "histogram_quantile(0.95, rate(dapr_component_pubsub_ingress_latencies_bucket{app_id=\"consumer\"}[5m]))",
      "legendFormat": "P95"
    },
    {
      "expr": "histogram_quantile(0.99, rate(dapr_component_pubsub_ingress_latencies_bucket{app_id=\"consumer\"}[5m]))",
      "legendFormat": "P99"
    }
  ]
}
```

#### **面板4：按Topic分析**
```json
{
  "title": "Per-Topic Metrics",
  "targets": [
    {
      "expr": "rate(dapr_component_pubsub_ingress_count{component=\"pubsub\"}[5m])",
      "legendFormat": "{{topic}} - {{app_id}}"
    }
  ]
}
```

## 🚨 告警规则对比

### **Knative 告警规则**

#### **平台级告警**
```yaml
groups:
- name: knative.eventing
  rules:
  - alert: BrokerHighErrorRate
    expr: |
      (
        rate(event_count{broker_name="default", response_code!="202"}[5m]) /
        rate(event_count{broker_name="default"}[5m])
      ) > 0.05
    for: 2m
    labels:
      severity: warning
    annotations:
      summary: "Broker {{$labels.broker_name}} has high error rate"
      
  - alert: TriggerProcessingLatencyHigh
    expr: |
      histogram_quantile(0.95, rate(event_processing_latencies_bucket{trigger_name=~".*"}[5m])) > 1000
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Trigger {{$labels.trigger_name}} has high processing latency"

  - alert: EventSourceDown
    expr: |
      rate(event_count{event_source=~".*"}[5m]) == 0
    for: 10m
    labels:
      severity: critical
    annotations:
      summary: "Event source {{$labels.event_source}} stopped producing events"
```

### **Dapr 告警规则**

#### **业务级告警**
```yaml
groups:
- name: dapr.pubsub
  rules:
  - alert: MessageBacklogHigh
    expr: |
      (
        sum(dapr_component_pubsub_egress_count{component="pubsub", topic="pod-events"}) -
        sum(dapr_component_pubsub_ingress_count{component="pubsub", topic="pod-events"})
      ) > 1000
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Message backlog is high: {{$value}} messages"
      description: "Topic pod-events has {{$value}} unprocessed messages"

  - alert: ConsumerProcessingFailure
    expr: |
      (
        rate(dapr_component_pubsub_ingress_count{process_status="failure"}[5m]) /
        rate(dapr_component_pubsub_ingress_count[5m])
      ) > 0.10
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "Consumer {{$labels.app_id}} has high failure rate"

  - alert: ProcessingLatencyHigh
    expr: |
      histogram_quantile(0.95, rate(dapr_component_pubsub_ingress_latencies_bucket{app_id="consumer"}[5m])) > 5000
    for: 3m
    labels:
      severity: warning
    annotations:
      summary: "Consumer {{$labels.app_id}} processing latency is high"

  - alert: PublisherDown
    expr: |
      rate(dapr_component_pubsub_egress_count{app_id="producer"}[5m]) == 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Publisher {{$labels.app_id}} stopped publishing messages"

  - alert: ConsumerLag
    expr: |
      (
        rate(dapr_component_pubsub_egress_count{component="pubsub"}[5m]) -
        rate(dapr_component_pubsub_ingress_count{component="pubsub"}[5m])
      ) > 10
    for: 3m
    labels:
      severity: warning
    annotations:
      summary: "Consumer is lagging behind producer"
```

## 📊 监控能力评估表

| 监控维度 | Knative | Dapr | 说明 |
|---------|---------|------|------|
| **消息堆积计算精度** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Dapr 有精确的 egress/ingress count |
| **Prometheus 查询复杂度** | ⭐⭐ | ⭐⭐⭐⭐⭐ | Knative 需要复杂的组合查询 |
| **Grafana Dashboard 开发** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Dapr 指标更直观易用 |
| **告警规则设置** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Dapr 告警条件更精确 |
| **开箱即用程度** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Dapr 指标自动暴露 |
| **平台组件监控** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | Knative 提供更多平台细节 |
| **业务指标精度** | ⭐⭐ | ⭐⭐⭐⭐⭐ | Dapr 提供真实的业务处理指标 |

## 🎯 具体场景分析

### **场景1：监控消息堆积**

#### **Knative 方案**
```prometheus
# 需要估算，不够精确
(
  increase(event_count{broker_name="default", response_code="202"}[1h]) -
  increase(event_count{trigger_name=~".*", response_code="200"}[1h])
)
```
**问题**：
- 无法区分不同 Topic
- 统计颗粒度粗糙
- 需要人工调整时间窗口

#### **Dapr 方案**
```prometheus
# 精确计算，按 Topic 分组
sum by (topic) (
  dapr_component_pubsub_egress_count{component="pubsub"} -
  dapr_component_pubsub_ingress_count{component="pubsub"}
)
```
**优势**：
- ✅ 精确到消息级别
- ✅ 自动按 Topic 分组
- ✅ 实时准确数据

### **场景2：监控处理延迟**

#### **Knative 获得的延迟**
```prometheus
# 主要是平台分发延迟，不是业务处理延迟
histogram_quantile(0.95, 
  rate(event_processing_latencies_bucket{trigger_name="demo-event-trigger"}[5m])
)
```

#### **Dapr 获得的延迟**
```prometheus
# 真实的业务处理延迟
histogram_quantile(0.95,
  rate(dapr_component_pubsub_ingress_latencies_bucket{app_id="consumer"}[5m])
)
```

### **场景3：故障排查**

#### **Knative 排查流程**
1. 检查 Broker 是否接收事件
2. 检查 Trigger 是否过滤正确
3. 检查应用是否响应
4. **需要查看应用日志确认业务处理状态**

#### **Dapr 排查流程**
1. 检查 egress_count（发布是否成功）
2. 检查 ingress_count（消费是否成功）
3. 检查 process_status（处理是否成功）
4. **通过指标就能确定问题环节**

## 🎉 总结

### **在 Prometheus + Grafana 环境下**

#### **选择 Dapr 的优势**：
- ✅ **查询语句更简单**：直接的业务指标
- ✅ **Dashboard 更易构建**：指标含义清晰
- ✅ **告警更精确**：基于真实业务状态
- ✅ **故障排查更高效**：指标覆盖完整

#### **选择 Knative 的优势**：
- ✅ **平台监控更全面**：Broker/Trigger/Channel 状态
- ✅ **事件路由分析**：事件在平台内的流转
- ✅ **多租户监控**：按 namespace 隔离

### **针对您的需求（消息堆积和消费速度）**

**Dapr + Prometheus + Grafana** 提供了：
- 🎯 **一行查询**即可获得精确的消息堆积数
- 🎯 **标准的 rate() 函数**即可获得消费速度
- 🎯 **简单的告警规则**基于准确的业务指标

**Knative + Prometheus + Grafana** 需要：
- ❌ **复杂的组合查询**来估算堆积
- ❌ **额外的应用指标**来补充业务监控
- ❌ **更多的开发工作**来实现精确监控

**结论：即使在标准监控栈下，Dapr 在消息监控方面仍然明显更优。** 