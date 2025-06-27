# Consumer Service (已弃用)

> ⚠️ **注意**: 此目录中的代码已不再使用！

## 新的实现方式

Consumer 现在使用 **通用 Python 镜像 + ConfigMap** 的方式部署，无需构建自定义镜像。

### 当前代码位置
- **ConfigMap**: `infrastructure/kubernetes/consumer-configmap.yaml`
- **部署配置**: `infrastructure/knative/services.yaml`

### 优势
- ✅ 无需构建镜像，部署更快
- ✅ 代码修改只需更新 ConfigMap
- ✅ 适合演示和开发环境
- ✅ 使用 Gunicorn 提供生产级性能

## 功能特性

Consumer 现在会：
- 智能处理三种事件类型
- 运行 2 个副本实现负载均衡
- 提供详细的处理日志
- 支持健康检查和指标收集

## API 接口

- `POST /` - 接收 CloudEvents (Knative 事件入口)
- `GET /health` - 健康检查
- `GET /metrics` - 指标信息
- `GET /stats` - 详细统计信息

## 查看日志

```bash
# 查看 Consumer 实时日志
kubectl logs -f deployment/event-consumer -n knative-demo

# 测试健康检查 (需要端口转发)
kubectl port-forward service/event-consumer-service 8080:80 -n knative-demo
curl http://localhost:8080/health
```

## 修改配置

如果需要修改 Consumer 的行为：

1. 编辑 `infrastructure/kubernetes/consumer-configmap.yaml`
2. 重新应用配置：
   ```bash
   kubectl apply -f infrastructure/kubernetes/consumer-configmap.yaml
   kubectl rollout restart deployment/event-consumer -n knative-demo
   ```

---

> 📝 此目录保留用于参考历史实现方式 