# Dapr 指标监控完全指南

## 🎯 监控目标

监控 Dapr + Redis Pub/Sub 的：
- **消息堆积情况**
- **消费速度**
- **发布速度**
- **延迟分布**
- **错误率**

## 📊 Dapr 内置指标详解

### 1. 消息发布指标 (Egress)

```prometheus
# 发布消息总数
dapr_component_pubsub_egress_count{app_id="simple-test-fixed",component="pubsub",topic="pod-events"} 53

# 发布延迟分布（histogram）
dapr_component_pubsub_egress_latencies_bucket{...le="5"} 53    # ≤5ms 的请求数
dapr_component_pubsub_egress_latencies_bucket{...le="50"} 53   # ≤50ms 的请求数
```

**关键监控点**：
- 发布成功率：`success="true"` vs `success="false"`
- 发布延迟：大部分请求应该在低延迟桶中
- 发布速率：通过时间差计算 msgs/sec

### 2. 消息接收指标 (Ingress)

```prometheus
# 接收消息总数
dapr_component_pubsub_ingress_count{app_id="simple-test-fixed",component="pubsub",topic="pod-events"} 182

# 接收处理延迟分布
dapr_component_pubsub_ingress_latencies_bucket{...le="5"} 123   # ≤5ms 处理的消息数
dapr_component_pubsub_ingress_latencies_bucket{...le="50"} 182  # ≤50ms 处理的消息数
```

**关键监控点**：
- 处理成功率：`process_status="success"`
- 处理延迟：应用处理消息的速度
- 消费速率：通过时间差计算消费速度

### 3. HTTP 服务器指标

```prometheus
# HTTP 请求总数（包括 /dapr/subscribe, /pod-events 等）
dapr_http_server_request_count 194

# HTTP 响应延迟
dapr_http_server_latency{...le="50"} 194
```

## 🚨 消息堆积监控

### 堆积检测公式

```bash
# 在单个生产者-消费者场景中
backlog = egress_count - ingress_count

# 多个生产者的情况
total_egress = sum(all_producer_egress_count)
total_ingress = sum(all_consumer_ingress_count)
global_backlog = total_egress - total_ingress
```

### 堆积状态判断

- `backlog > 0`: ⚠️ **存在消息积压**（生产快于消费）
- `backlog == 0`: ✅ **收发平衡**
- `backlog < 0`: ✅ **消费领先**（消费快于生产，正常状态）

## 📈 性能监控指标

### 1. 实时监控脚本

```bash
# 使用我们的 Dapr 指标监控工具
./scripts/dapr-metrics-monitor.sh

# 选择模式：
# 1) 详细指标分析 - 完整的指标报告
# 2) 实时指标监控 - 持续监控关键指标
# 3) 性能基准测试 - 60秒性能测试
# 4) 快速状态检查 - 关键指标快速查看
```

### 2. 关键性能指标

从实际运行结果可以看到：

**Pod: dapr-simple-test-fixed**
- 📤 **发布**: 53 条消息
- 📥 **接收**: 182 条消息  
- ⚖️ **状态**: 消费领先 +129
- 🌐 **HTTP请求**: 194 次
- ⏱️ **延迟**: 100% 请求 ≤50ms

**性能分析**：
- ✅ **无消息积压**：接收数 > 发布数
- ✅ **低延迟**：所有请求都在50ms内完成
- ✅ **高成功率**：没有失败的消息

### 3. 消费速度计算

```bash
# 60秒内的消费速度
consumption_rate = (end_ingress_count - start_ingress_count) / 60
```

## 🔧 使用工具

### 1. 快速检查

```bash
./scripts/dapr-metrics-monitor.sh
# 选择 4) 快速状态检查
```

### 2. Prometheus查询（如果有Prometheus）

```prometheus
# 发布速率 (messages/second)
rate(dapr_component_pubsub_egress_count[1m])

# 接收速率 (messages/second)  
rate(dapr_component_pubsub_ingress_count[1m])

# 堆积情况
(
  sum(dapr_component_pubsub_egress_count{component="pubsub"}) 
  - 
  sum(dapr_component_pubsub_ingress_count{component="pubsub"})
)

# P95 发布延迟
histogram_quantile(0.95, dapr_component_pubsub_egress_latencies)

# P95 处理延迟
histogram_quantile(0.95, dapr_component_pubsub_ingress_latencies)
```

### 3. Redis Stream 直接监控（补充）

如果需要更详细的队列状态：

```bash
# 安装 redis-cli (可选)
brew install redis  # macOS

# 运行 Redis 监控
./scripts/monitor-redis-streams.sh
```

## 📊 监控仪表板建议

### 关键指标面板

1. **消息流量**
   - 发布速率 (msgs/sec)
   - 接收速率 (msgs/sec)  
   - 堆积数量

2. **延迟监控**
   - P50, P95, P99 发布延迟
   - P50, P95, P99 处理延迟

3. **错误监控**
   - 发布失败率
   - 处理失败率
   - HTTP 错误率

4. **资源使用**
   - CPU 使用率
   - 内存使用率
   - 网络 I/O

## 🚨 告警规则建议

```yaml
# 消息积压告警
- alert: DaprMessageBacklog
  expr: sum(dapr_component_pubsub_egress_count) - sum(dapr_component_pubsub_ingress_count) > 100
  for: 5m
  
# 高延迟告警  
- alert: DaprHighLatency
  expr: histogram_quantile(0.95, dapr_component_pubsub_ingress_latencies) > 1000
  for: 2m

# 发布失败告警
- alert: DaprPublishFailure
  expr: rate(dapr_component_pubsub_egress_count{success="false"}[5m]) > 0.1
  for: 1m
```

## 🎯 总结

**Dapr 提供了完整的内置指标系统**，可以精确监控：

✅ **消息堆积**：通过 egress/ingress count 对比  
✅ **消费速度**：通过指标增长率计算  
✅ **延迟分布**：通过 histogram 精确分析  
✅ **成功率**：通过 success/failure 标签统计  
✅ **实时性**：指标实时更新，支持秒级监控  

**相比传统方案的优势**：
- 📊 **标准化**：Prometheus 格式，易于集成
- 🔍 **详细性**：提供完整的延迟分布信息  
- 🎯 **准确性**：直接来源于 Dapr sidecar，数据准确
- 🚀 **易用性**：通过我们的监控脚本即可使用 