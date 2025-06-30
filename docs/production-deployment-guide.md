# Knative Demo 生产环境部署指南

## 生产环境架构概览

### 整体架构
- **多个生产者**: 3-5个不同业务域的事件生产者
- **多个消费者**: 8-10个专门处理不同事件类型的消费者
- **多个Trigger**: 15-20个细粒度事件路由规则
- **消息持久化**: Kafka 集群作为事件存储后端
- **高可用性**: 所有组件多副本部署

## 必需安装的基础工具

### 1. Kubernetes 集群
- **版本要求**: >= 1.26
- **节点数量**: 最少 3个 Worker节点（生产推荐 5-7个）
- **资源配置**: 每节点最少 8GB RAM, 4 CPU cores
- **存储**: 支持动态存储卷（PV/PVC）

### 2. Helm 包管理器
- **版本要求**: >= 3.8
- **用途**: 安装 Kafka、监控组件等
- **安装方式**: 
  ```bash
  curl https://get.helm.sh/helm-v3.12.0-linux-amd64.tar.gz
  ```

### 3. kubectl 命令行工具
- **版本要求**: 与 K8s 集群版本兼容
- **用途**: 集群管理和应用部署

## 核心 Knative 组件

### 1. Knative Eventing（必需安装）
```yaml
组件清单:
- knative-eventing-core
- knative-eventing-mtbroker  
- knative-eventing-kafka (用于Kafka集成)
```

**安装方式**: YAML 清单或 Operator
**维护责任**: 平台团队维护

### 2. Knative Serving（可选）
- **是否需要**: 可选，如果需要 Serverless 功能
- **维护责任**: 平台团队维护

## 消息队列系统（二选一）

### 选项1: Apache Kafka（推荐）

#### A. Strimzi Operator（推荐生产环境）
```yaml
安装组件:
- Strimzi Cluster Operator
- Kafka Cluster (3个Broker节点)
- Zookeeper Cluster (3个节点)  
- Kafka Bridge
- Kafka Exporter (监控)
```

**维护责任**: 
- ✅ **自动化维护**: Strimzi Operator 管理 Kafka 生命周期
- ❌ **需要维护**: Operator 本身的升级和配置

#### B. Confluent Platform（企业级）
```yaml
安装组件:
- Confluent Operator
- Kafka Cluster
- Schema Registry
- Kafka Connect
- Control Center (管理界面)
```

**维护责任**:
- ✅ **商业支持**: Confluent 提供企业支持
- ❌ **需要维护**: 许可证管理和配置调优

### 选项2: RabbitMQ

#### RabbitMQ Cluster Operator
```yaml
安装组件:
- RabbitMQ Cluster Operator
- RabbitMQ Cluster (3个节点)
- RabbitMQ Management Plugin
```

**维护责任**:
- ❌ **需要维护**: 集群配置、插件管理、性能调优

## 生产环境应用组件

### 1. 事件生产者（Producer）
```yaml
数量: 3-5个不同业务域
部署方式: Kubernetes Deployment
副本数: 每个生产者 2-3个副本
业务域示例:
- 用户服务生产者 (user-events-producer)
- 订单服务生产者 (order-events-producer)  
- 支付服务生产者 (payment-events-producer)
- 库存服务生产者 (inventory-events-producer)
- 通知服务生产者 (notification-events-producer)
```

**维护责任**: ❌ **业务团队维护** - 代码逻辑、业务规则

### 2. 事件消费者（Consumer）
```yaml
数量: 8-10个专门消费者
部署方式: Kubernetes Deployment  
副本数: 每个消费者 2-4个副本
消费者示例:
- 用户注册处理器 (user-registration-consumer)
- 订单支付处理器 (order-payment-consumer)
- 库存更新处理器 (inventory-update-consumer)
- 邮件通知处理器 (email-notification-consumer)
- 短信通知处理器 (sms-notification-consumer)
- 数据分析处理器 (analytics-consumer)
- 审计日志处理器 (audit-log-consumer)
- 搜索索引处理器 (search-index-consumer)
```

**维护责任**: ❌ **业务团队维护** - 处理逻辑、错误处理

### 3. Knative Trigger配置
```yaml
数量: 15-20个细粒度路由规则
配置示例:
- user.created → user-registration-consumer
- user.activated → email-notification-consumer + analytics-consumer
- order.placed → order-payment-consumer + inventory-update-consumer
- order.paid → email-notification-consumer + audit-log-consumer
- payment.failed → sms-notification-consumer + order-payment-consumer
- inventory.low → notification-events-producer
- user.deleted → audit-log-consumer + search-index-consumer
```

**维护责任**: ❌ **业务团队维护** - 路由规则、过滤条件

## 监控和可观测性组件

### 1. Prometheus + Grafana
```yaml
安装组件:
- Prometheus Operator
- Grafana
- AlertManager
- Node Exporter
- Kafka Exporter (如果使用Kafka)
```

**维护责任**: 
- ✅ **部分自动化**: Operator 管理部署
- ❌ **需要维护**: 告警规则、Dashboard 配置

### 2. 日志收集系统
```yaml
选项1 - ELK Stack:
- Elasticsearch Cluster
- Logstash/Fluentd
- Kibana

选项2 - Loki Stack:
- Loki
- Promtail  
- Grafana (复用监控的Grafana)
```

**维护责任**: ❌ **运维团队维护** - 存储管理、查询优化

### 3. 分布式追踪
```yaml
安装组件:
- Jaeger Operator
- Jaeger Collector
- Jaeger Query UI
```

**维护责任**: ❌ **运维团队维护** - 存储配置、性能调优

## 安全组件

### 1. RBAC 权限控制
```yaml
需要配置:
- ServiceAccount for each component
- Role and RoleBinding
- ClusterRole for cross-namespace access
```

**维护责任**: ❌ **安全团队维护** - 权限策略、定期审计

### 2. TLS 证书管理
```yaml
安装组件:
- cert-manager
- Let's Encrypt ClusterIssuer
- Internal CA Issuer
```

**维护责任**: 
- ✅ **自动化**: cert-manager 自动续期
- ❌ **需要维护**: 证书策略配置

### 3. 网络策略
```yaml
需要配置:
- NetworkPolicy for microsegmentation
- Istio Service Mesh (可选)
```

**维护责任**: ❌ **网络团队维护** - 策略规则、故障排查

## 存储需求

### 1. 持久化存储
```yaml
Kafka存储需求:
- 每个Broker: 500GB-1TB SSD
- Zookeeper: 20GB SSD per node
- 备份存储: 额外50%容量

监控存储需求:  
- Prometheus: 200GB-500GB
- Grafana: 50GB
- 日志存储: 1TB-5TB (根据日志量)
```

**维护责任**: ❌ **存储团队维护** - 容量规划、备份策略

## 网络要求

### 1. 负载均衡器
```yaml
需要:
- Ingress Controller (Nginx/Traefik)
- LoadBalancer Service (云环境)
- MetalLB (私有云环境)
```

**维护责任**: ❌ **网络团队维护** - 负载均衡规则、SSL终止

### 2. DNS 配置
```yaml
需要:
- 内部DNS解析 (CoreDNS)
- 外部域名解析
- 服务发现配置
```

**维护责任**: ❌ **网络团队维护** - DNS记录、解析策略

## 维护责任总结

### ✅ 自动化维护（无需人工干预）
- Knative Eventing 核心功能
- Strimzi Kafka 集群管理
- cert-manager 证书自动续期
- Kubernetes 自愈能力

### ❌ 需要人工维护

#### 平台团队负责:
- Knative 组件升级
- Kubernetes 集群维护
- Operator 版本管理

#### 业务团队负责:
- Producer/Consumer 应用代码
- Trigger 路由规则配置
- 业务逻辑错误处理

#### 运维团队负责:
- 监控告警规则配置
- 日志收集系统维护
- 性能调优和容量规划

#### 安全团队负责:
- RBAC 权限策略
- 安全扫描和漏洞修复
- 网络安全策略

## 总投入估算

### 人力投入:
- **平台团队**: 2-3人 (Knative + K8s维护)
- **运维团队**: 2-3人 (监控 + 日志维护)  
- **业务团队**: 5-8人 (应用开发维护)
- **安全团队**: 1-2人 (安全策略维护)

### 基础设施成本:
- **计算资源**: 10-15个节点 (生产+测试环境)
- **存储资源**: 5-10TB 持久化存储
- **网络资源**: 负载均衡器 + 带宽费用 