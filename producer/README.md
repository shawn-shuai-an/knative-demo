# Producer Service (已弃用)

> ⚠️ **注意**: 此目录中的代码已不再使用！

## 新的实现方式

Producer 现在使用 **通用 Python 镜像 + ConfigMap** 的方式部署，无需构建自定义镜像。

### 当前代码位置
- **ConfigMap**: `infrastructure/kubernetes/producer-configmap.yaml`
- **部署配置**: `infrastructure/knative/services.yaml`

### 优势
- ✅ 无需构建镜像，部署更快
- ✅ 代码修改只需更新 ConfigMap
- ✅ 适合演示和开发环境
- ✅ 自动定时发送事件

## 功能特性

Producer 现在会：
- 每 10 秒自动发送一个事件
- 轮流发送三种事件类型：`demo.event`、`user.created`、`order.placed`
- 生成真实的演示数据

## 查看日志

```bash
# 查看 Producer 实时日志
kubectl logs -f deployment/event-producer -n knative-demo
```

## 修改配置

如果需要修改 Producer 的行为：

1. 编辑 `infrastructure/kubernetes/producer-configmap.yaml`
2. 重新应用配置：
   ```bash
   kubectl apply -f infrastructure/kubernetes/producer-configmap.yaml
   kubectl rollout restart deployment/event-producer -n knative-demo
   ```

---

> 📝 此目录保留用于参考历史实现方式 