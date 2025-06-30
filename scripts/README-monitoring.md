# 📊 Dapr 监控工具使用指南

## 🚀 快速开始

```bash
# 1. 最推荐：使用 Dapr 内置指标监控
./scripts/dapr-metrics-monitor.sh

# 2. 备选：Redis Stream 直接监控 (需要 redis-cli)
./scripts/monitor-redis-streams.sh

# 3. Kubernetes 层面监控
./scripts/monitor-dapr-metrics.sh

# 4. 简单状态检查
./scripts/quick-monitor.sh
```

## 📈 监控工具对比

| 工具 | 优势 | 适用场景 |
|------|------|----------|
| **dapr-metrics-monitor.sh** | ✅ 最准确<br>✅ Prometheus 标准<br>✅ 延迟分布详细 | **首选**，生产环境监控 |
| monitor-redis-streams.sh | ✅ 底层数据<br>✅ Consumer Group 详情 | 深度排查，需要 redis-cli |
| monitor-dapr-metrics.sh | ✅ K8s 原生<br>✅ 日志分析 | 应用层监控 |
| quick-monitor.sh | ✅ 快速概览<br>✅ 多维度检查 | 日常巡检 |

## 📊 核心监控指标

### 从实际运行结果看到的指标：

```
📱 Pod: dapr-simple-test-fixed
📤 发布指标: 53 条消息，100% ≤50ms
📥 接收指标: 182 条消息，100% ≤50ms  
⚖️  消息流量: 消费领先 +129 (健康状态)
🌐 HTTP 请求: 194 次，全部成功
```

### 关键性能指标：

- **消息堆积**: `接收数 - 发布数` 
  - `> 0`: ⚠️ 积压（生产快于消费）
  - `< 0`: ✅ 健康（消费快于生产）
  
- **消费速度**: `(当前接收数 - 之前接收数) / 时间差`

- **延迟分布**: 
  - ≤5ms: 超快
  - ≤50ms: 正常  
  - >100ms: 需要关注

## 🎯 使用建议

### 日常监控
```bash
# 快速检查所有指标
echo "4" | ./scripts/dapr-metrics-monitor.sh
```

### 性能测试
```bash  
# 60秒基准测试
echo "3" | ./scripts/dapr-metrics-monitor.sh
```

### 实时监控
```bash
# 持续监控关键指标
echo "2" | ./scripts/dapr-metrics-monitor.sh
```

### 问题排查
```bash
# 详细指标分析
echo "1" | ./scripts/dapr-metrics-monitor.sh

# 结合 Redis 底层分析
./scripts/monitor-redis-streams.sh
```

## 🚨 告警建议

基于 Dapr 指标的告警规则：

```bash
# 消息积压检查
if [ $((egress_count - ingress_count)) -gt 100 ]; then
    echo "⚠️ 消息积压超过 100 条"
fi

# 高延迟检查  
if [ $(P95_latency) -gt 1000 ]; then
    echo "⚠️ P95 延迟超过 1 秒"
fi

# 错误率检查
if [ $(error_rate) -gt 0.01 ]; then
    echo "⚠️ 错误率超过 1%"
fi
```

## 📋 故障排查流程

1. **快速状态检查**
   ```bash
   ./scripts/quick-monitor.sh
   ```

2. **Dapr 指标分析**  
   ```bash
   echo "1" | ./scripts/dapr-metrics-monitor.sh
   ```

3. **应用日志检查**
   ```bash
   kubectl logs -n dapr-demo -l dapr.io/sidecar-injected=true -c app -f
   ```

4. **Redis 底层分析**
   ```bash
   ./scripts/monitor-redis-streams.sh
   ```

5. **网络连接检查**
   ```bash
   echo "4" | ./scripts/monitor-dapr-metrics.sh
   ```

## 🎉 总结

**Dapr 提供了企业级的监控能力**：

✅ **准确性**：直接来源于 sidecar 的精确指标  
✅ **标准化**：Prometheus 格式，易于集成 Grafana  
✅ **完整性**：覆盖发布、接收、延迟、错误等所有维度  
✅ **实时性**：秒级更新，支持实时告警  

使用我们的监控工具，您可以：
- 📊 **实时掌握**消息流量和堆积情况
- 🔍 **精确分析**延迟分布和性能瓶颈  
- 🚨 **及时发现**异常和故障
- 📈 **优化性能**基于数据驱动的决策 