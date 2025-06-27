# Knative Infrastructure

包含 Knative 基础设施的所有配置文件和部署脚本。

## 目录结构

```
infrastructure/
├── knative/                    # Knative 资源配置
│   ├── namespace.yaml         # 命名空间
│   ├── broker.yaml           # 事件 Broker
│   ├── trigger.yaml          # 事件触发器
│   └── services.yaml         # Knative 服务
├── kubernetes/               # 原生 K8s 资源
│   └── configmap.yaml       # 配置映射
└── scripts/                 # 部署脚本
    ├── setup.sh            # 环境初始化
    └── cleanup.sh          # 环境清理
```

## 组件说明

### Broker
- 事件路由中心，接收来自生产者的事件
- 支持事件过滤和转发

### Trigger  
- 定义事件路由规则
- 将特定类型的事件转发给对应的消费者

### Services
- 定义 Knative 服务配置
- 包含生产者和消费者的服务定义

## 部署命令

```bash
# 初始化环境
./scripts/setup.sh

# 清理环境
./scripts/cleanup.sh
```

## 验证部署

```bash
# 检查 Broker 状态
kubectl get broker -n knative-demo

# 检查 Trigger 状态  
kubectl get trigger -n knative-demo

# 检查服务状态
kubectl get ksvc -n knative-demo
``` 