#!/bin/bash

# 无需构建镜像 - 使用通用 Python 镜像

set -e

echo "ℹ️  此项目使用通用镜像，无需构建自定义镜像"
echo ""
echo "📦 使用的镜像:"
echo "- Producer: python:3.11-slim (通用镜像)"
echo "- Consumer: python:3.11-slim (通用镜像)"
echo ""
echo "🗂️  代码通过 ConfigMap 注入:"
echo "- Producer 代码: infrastructure/kubernetes/producer-configmap.yaml"
echo "- Consumer 代码: infrastructure/kubernetes/consumer-configmap.yaml"
echo ""
echo "💡 下一步："
echo "cd infrastructure && ./scripts/setup.sh" 