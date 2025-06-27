#!/bin/bash

# 完整的部署脚本 (无需构建镜像)

set -e

echo "🚀 开始完整的部署流程..."

# 获取项目根目录
PROJECT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$PROJECT_ROOT"

echo "📍 当前目录: $PROJECT_ROOT"

# 步骤1: 检查镜像状态
echo ""
echo "=== 步骤 1/2: 检查镜像状态 ==="
./scripts/build-all.sh

# 步骤2: 部署基础设施
echo ""
echo "=== 步骤 2/2: 部署 Knative 基础设施 ==="
cd infrastructure
./scripts/setup.sh

echo ""
echo "🎉 完整部署流程完成！"
echo ""
echo "🔗 快速验证:"
echo "# 查看 Producer 自动发送事件:"
echo "kubectl logs -f deployment/event-producer -n knative-demo"
echo ""
echo "# 查看 Consumer 处理事件:"
echo "kubectl logs -f deployment/event-consumer -n knative-demo"
echo ""
echo "🧪 自动化测试:"
echo "./scripts/quick-test.sh" 