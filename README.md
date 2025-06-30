# Knative Demo Project

这是一个基于 Knative 的完整演示项目，展示了事件驱动架构的实现，并提供了与 Dapr 的全面对比分析。

## 项目结构

```
knative_demo/
├── producer/           # 事件生产者服务
├── consumer/           # 事件消费者服务
├── infrastructure/     # Knative 基础设施配置
├── scripts/           # 部署和管理脚本
├── docs/              # 详细文档
└── dapr/              # Dapr 对比实现
```

## 🚀 快速开始

### 前置条件
- Kubernetes 集群 (v1.28+)
- kubectl 已配置
- 已安装 Knative Eventing

### 部署演示
```bash
# 部署 Knative 演示
./scripts/deploy-all.sh

# 查看运行状态
kubectl get pods -n knative-demo
kubectl get triggers -n knative-demo

# 清理资源
./scripts/cleanup.sh
```

## 📊 Knative vs Dapr 对比分析

本项目提供了 Knative 和 Dapr 的全面对比分析，包括：

### 🎯 系统资源要求对比

| 维度 | Knative | Dapr | 优势方 |
|------|---------|------|---------|
| **集群最低要求** | 6 cores + 6GB | 2 cores + 2GB | Dapr |
| **Control Plane** | 520m CPU + 520Mi | 550m CPU + 235Mi | 接近 |
| **应用扩展性** | 固定开销 | 线性增长 | **Knative** |
| **100 应用总开销** | 520m + 520Mi | 10.6 cores + 25Gi | **Knative** |

**关键洞察**：
- 小规模（<10 服务）：Dapr 开销可接受
- 中大规模（>50 服务）：**Knative 有压倒性优势**
- 成本差异：在大规模部署中可达 **8-10 倍**

### 📈 监控能力对比

| 监控维度 | Knative | Dapr | 说明 |
|---------|---------|------|------|
| **消息堆积计算** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Dapr 提供精确指标 |
| **Prometheus 查询** | 复杂 | 简单 | Dapr 一行查询获得结果 |
| **Grafana Dashboard** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Dapr 指标更直观 |
| **业务指标精度** | ⭐⭐ | ⭐⭐⭐⭐⭐ | Dapr 提供真实业务延迟 |

### 🔧 架构模式对比

**Knative**：事件扇出模式
```
Producer → Broker → Trigger → Consumer (多播)
```

**Dapr**：竞争消费模式
```
Publisher → Pub/Sub Component → Subscriber (单播)
```

## 🛠️ 实用工具

### 资源监控对比
```bash
# 实时监控资源使用
./scripts/resource-monitoring-comparison.sh monitor

# 持续监控模式
./scripts/resource-monitoring-comparison.sh continuous 5

# 导出监控数据
./scripts/resource-monitoring-comparison.sh export
```

### 技术选型建议
```bash
# 快速对比总结
./scripts/resource-requirements-summary.sh

# 交互式推荐
./scripts/resource-requirements-summary.sh interactive

# 查看优化建议
./scripts/resource-requirements-summary.sh optimize
```

### Prometheus + Grafana 监控
```bash
# 部署标准监控栈
./scripts/prometheus-grafana-comparison.sh deploy

# 查看查询语句对比
./scripts/prometheus-grafana-comparison.sh queries

# 监控能力对比
./scripts/prometheus-grafana-comparison.sh compare
```

## 📚 详细文档

### 核心对比文档
- [系统资源要求对比](docs/system-resource-requirements-comparison.md)
- [Prometheus + Grafana 监控对比](docs/prometheus-grafana-monitoring-comparison.md)
- [架构总结](docs/architecture-summary.md)

### 特定场景分析
- [单一消费者场景对比](docs/single-consumer-comparison.md)
- [多消费者场景对比](docs/multi-consumer-scenario.md)
- [消费者组机制分析](docs/consumer-group-mechanism.md)
- [多语言支持对比](docs/multi-language-comparison.md)

### 实施指南
- [生产部署指南](docs/production-deployment-guide.md)
- [Dapr 安装指南](docs/dapr-installation-guide.md)
- [监控配置指南](docs/dapr-metrics-monitoring-guide.md)

## 🎯 选择建议

### 选择 Knative 的场景
- ✅ **大规模部署**（>50 服务）
- ✅ **成本敏感**项目
- ✅ **事件驱动**架构为主
- ✅ **Serverless** 需求

### 选择 Dapr 的场景
- ✅ **小规模部署**（<50 服务）
- ✅ **低延迟**要求
- ✅ **丰富微服务功能**需求
- ✅ **多语言混合**开发

## 🔍 项目特色

### 零镜像构建架构
- Producer 和 Consumer 都使用通用镜像
- 代码通过 ConfigMap 注入
- 完全不需要构建自定义镜像

### 多事件类型支持
- `demo.event` - 演示事件
- `user.created` - 用户创建事件
- `order.placed` - 订单创建事件

### 完整监控方案
- 实时资源使用监控
- 消息堆积和处理速度监控
- 成本分析和优化建议

## 🤝 贡献

欢迎提交 Issue 和 Pull Request 来改进这个项目！

## 📄 许可证

本项目采用 MIT 许可证。 