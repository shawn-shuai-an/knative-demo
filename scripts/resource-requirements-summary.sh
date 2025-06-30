#!/bin/bash
# 资源要求对比总结脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================================"
echo -e "🎯 Knative vs Dapr 资源要求对比总结"
echo -e "================================================================"
echo -e "${NC}"

# 显示官方要求对比
show_official_requirements() {
    echo -e "${CYAN}📋 官方资源要求对比${NC}"
    echo -e "${YELLOW}=================================================${NC}"
    echo ""
    
    echo -e "${GREEN}Knative 官方要求:${NC}"
    echo -e "  单节点部署: 6 CPUs + 6 GB 内存 + 30 GB 磁盘"
    echo -e "  多节点部署: 每节点 2 CPUs + 4 GB 内存 + 20 GB 磁盘"
    echo -e "  Kubernetes: v1.28+"
    echo ""
    
    echo -e "${PURPLE}Dapr 官方要求:${NC}"
    echo -e "  Control Plane: 550m CPU + 235Mi 内存"
    echo -e "  每个 Sidecar: 100m CPU + 250Mi 内存"
    echo -e "  推荐集群: 3+ 工作节点（HA 模式）"
    echo -e "  Kubernetes: 遵循 Version Skew Policy"
    echo ""
}

# 显示规模化资源对比
show_scale_comparison() {
    echo -e "${CYAN}📊 规模化部署资源对比${NC}"
    echo -e "${YELLOW}=================================================${NC}"
    echo ""
    
    printf "%-15s %-20s %-20s %-15s\n" "部署规模" "Knative 总开销" "Dapr 总开销" "倍数差异"
    printf "%-15s %-20s %-20s %-15s\n" "-------" "---------------" "------------" "-------"
    printf "%-15s %-20s %-20s %-15s\n" "10 应用" "520m CPU + 520Mi" "1.55 CPU + 2.7Gi" "~3x"
    printf "%-15s %-20s %-20s %-15s\n" "100 应用" "520m CPU + 520Mi" "10.6 CPU + 25Gi" "~20x"
    printf "%-15s %-20s %-20s %-15s\n" "1000 应用" "520m CPU + 520Mi" "100.6 CPU + 244Gi" "~200x"
    echo ""
    
    echo -e "${YELLOW}💡 关键洞察:${NC}"
    echo -e "  • Knative: 资源开销几乎固定，不随应用数量增长"
    echo -e "  • Dapr: 资源开销与应用数量线性增长"
    echo -e "  • 临界点: ~10 个应用后，Knative 开始显现优势"
    echo ""
}

# 显示成本影响分析
show_cost_analysis() {
    echo -e "${CYAN}💰 云环境成本影响分析 (AWS EKS)${NC}"
    echo -e "${YELLOW}=================================================${NC}"
    echo ""
    
    printf "%-15s %-20s %-20s %-15s\n" "部署规模" "Knative 成本/月" "Dapr 成本/月" "成本差异"
    printf "%-15s %-20s %-20s %-15s\n" "-------" "---------------" "------------" "-------"
    printf "%-15s %-20s %-20s %-15s\n" "100 应用" "\$140-280" "\$420-560" "3-4x"
    printf "%-15s %-20s %-20s %-15s\n" "1000 应用" "\$280-420" "\$2800-3500" "8-10x"
    echo ""
    
    echo -e "${YELLOW}💡 成本分析:${NC}"
    echo -e "  • 小规模部署: 成本差异可接受"
    echo -e "  • 中大规模部署: Knative 成本优势明显"
    echo -e "  • 规模越大，Knative 成本优势越突出"
    echo ""
}

# 显示选择建议
show_selection_guide() {
    echo -e "${CYAN}🎯 技术选型建议${NC}"
    echo -e "${YELLOW}=================================================${NC}"
    echo ""
    
    echo -e "${GREEN}选择 Knative 的场景:${NC}"
    echo -e "  ✅ 大规模部署 (>50 服务)"
    echo -e "  ✅ 成本敏感项目"
    echo -e "  ✅ 事件驱动架构为主"
    echo -e "  ✅ Serverless 需求"
    echo -e "  ✅ 资源受限环境"
    echo ""
    
    echo -e "${PURPLE}选择 Dapr 的场景:${NC}"
    echo -e "  ✅ 小规模部署 (<50 服务)"
    echo -e "  ✅ 低延迟要求"
    echo -e "  ✅ 需要丰富的微服务功能"
    echo -e "  ✅ 服务网格功能需求"
    echo -e "  ✅ 多语言混合开发"
    echo ""
}

# 显示优化建议
show_optimization_tips() {
    echo -e "${CYAN}⚡ 资源优化建议${NC}"
    echo -e "${YELLOW}=================================================${NC}"
    echo ""
    
    echo -e "${GREEN}Knative 优化:${NC}"
    echo -e "  • 调整 Control Plane 资源限制"
    echo -e "  • 选择性部署不需要的组件"
    echo -e "  • 配置 Zero-scale 减少资源浪费"
    echo ""
    
    echo -e "${PURPLE}Dapr 优化:${NC}"
    echo -e "  • 微调 Sidecar 资源配置"
    echo -e "  • 按需启用组件（mTLS、Actor等）"
    echo -e "  • 考虑 Dapr Shared 模式"
    echo -e "  • 设置合理的软内存限制"
    echo ""
}

# 交互式选择建议
interactive_recommendation() {
    echo -e "${CYAN}🤖 交互式技术选型建议${NC}"
    echo -e "${YELLOW}=================================================${NC}"
    echo ""
    
    # 收集用户需求
    echo -e "${BLUE}请回答以下问题，我将为您推荐最适合的方案：${NC}"
    echo ""
    
    # 规模问题
    echo -e "${YELLOW}1. 您预期的服务数量规模？${NC}"
    echo "   a) 小规模 (<10 服务)"
    echo "   b) 中等规模 (10-50 服务)"
    echo "   c) 大规模 (>50 服务)"
    read -p "请选择 (a/b/c): " scale_choice
    
    # 成本敏感度
    echo -e "${YELLOW}2. 对运营成本的敏感度？${NC}"
    echo "   a) 功能优先，成本次要"
    echo "   b) 平衡功能和成本"
    echo "   c) 成本优先，功能够用即可"
    read -p "请选择 (a/b/c): " cost_choice
    
    # 架构类型
    echo -e "${YELLOW}3. 主要的应用架构类型？${NC}"
    echo "   a) 事件驱动架构"
    echo "   b) 微服务架构"
    echo "   c) 混合架构"
    read -p "请选择 (a/b/c): " arch_choice
    
    # 团队技能
    echo -e "${YELLOW}4. 团队对 Kubernetes 的熟悉程度？${NC}"
    echo "   a) 初学者"
    echo "   b) 中等水平"
    echo "   c) 专家级别"
    read -p "请选择 (a/b/c): " skill_choice
    
    echo ""
    echo -e "${CYAN}📊 分析您的需求...${NC}"
    sleep 2
    
    # 计算推荐分数
    local knative_score=0
    local dapr_score=0
    
    # 规模评分
    case $scale_choice in
        a) dapr_score=$((dapr_score + 3)); knative_score=$((knative_score + 1)) ;;
        b) dapr_score=$((dapr_score + 2)); knative_score=$((knative_score + 2)) ;;
        c) dapr_score=$((dapr_score + 1)); knative_score=$((knative_score + 3)) ;;
    esac
    
    # 成本评分
    case $cost_choice in
        a) dapr_score=$((dapr_score + 3)); knative_score=$((knative_score + 1)) ;;
        b) dapr_score=$((dapr_score + 2)); knative_score=$((knative_score + 2)) ;;
        c) dapr_score=$((dapr_score + 1)); knative_score=$((knative_score + 3)) ;;
    esac
    
    # 架构评分
    case $arch_choice in
        a) dapr_score=$((dapr_score + 1)); knative_score=$((knative_score + 3)) ;;
        b) dapr_score=$((dapr_score + 3)); knative_score=$((knative_score + 1)) ;;
        c) dapr_score=$((dapr_score + 2)); knative_score=$((knative_score + 2)) ;;
    esac
    
    # 技能评分
    case $skill_choice in
        a) dapr_score=$((dapr_score + 2)); knative_score=$((knative_score + 1)) ;;
        b) dapr_score=$((dapr_score + 2)); knative_score=$((knative_score + 2)) ;;
        c) dapr_score=$((dapr_score + 1)); knative_score=$((knative_score + 3)) ;;
    esac
    
    # 显示推荐结果
    echo -e "${GREEN}✨ 推荐结果：${NC}"
    echo ""
    
    if [ $knative_score -gt $dapr_score ]; then
        echo -e "${GREEN}🎯 推荐选择: Knative${NC}"
        echo -e "匹配度: ${GREEN}$knative_score/12${NC} vs Dapr: ${YELLOW}$dapr_score/12${NC}"
        echo ""
        echo -e "${YELLOW}推荐理由:${NC}"
        echo -e "  • 在您的使用场景下，Knative 更适合"
        echo -e "  • 特别是在规模和成本方面有优势"
        echo -e "  • 事件驱动架构是 Knative 的强项"
    elif [ $dapr_score -gt $knative_score ]; then
        echo -e "${PURPLE}🎯 推荐选择: Dapr${NC}"
        echo -e "匹配度: ${PURPLE}$dapr_score/12${NC} vs Knative: ${YELLOW}$knative_score/12${NC}"
        echo ""
        echo -e "${YELLOW}推荐理由:${NC}"
        echo -e "  • 在您的使用场景下，Dapr 更适合"
        echo -e "  • 丰富的微服务功能满足您的需求"
        echo -e "  • 开发友好度和功能完整性更好"
    else
        echo -e "${YELLOW}🤔 两者评分相近，建议根据具体情况选择${NC}"
        echo -e "Knative: ${GREEN}$knative_score/12${NC} vs Dapr: ${PURPLE}$dapr_score/12${NC}"
        echo ""
        echo -e "${YELLOW}建议:${NC}"
        echo -e "  • 可以先小规模试点两种方案"
        echo -e "  • 根据团队反馈和实际性能表现决定"
    fi
    
    echo ""
}

# 显示下一步建议
show_next_steps() {
    echo -e "${CYAN}🚀 下一步行动建议${NC}"
    echo -e "${YELLOW}=================================================${NC}"
    echo ""
    
    echo -e "${GREEN}1. 实际测试:${NC}"
    echo -e "   ./scripts/resource-monitoring-comparison.sh monitor"
    echo ""
    
    echo -e "${GREEN}2. 部署演示:${NC}"
    echo -e "   # Knative 演示"
    echo -e "   ./scripts/deploy-all.sh"
    echo -e "   # Dapr 演示"
    echo -e "   ./scripts/test-dapr.sh"
    echo ""
    
    echo -e "${GREEN}3. 监控对比:${NC}"
    echo -e "   ./scripts/prometheus-grafana-comparison.sh deploy"
    echo ""
    
    echo -e "${GREEN}4. 查看详细文档:${NC}"
    echo -e "   docs/system-resource-requirements-comparison.md"
    echo -e "   docs/prometheus-grafana-monitoring-comparison.md"
    echo ""
}

# 主程序
case "${1:-}" in
    "requirements")
        show_official_requirements
        ;;
    "scale")
        show_scale_comparison
        ;;
    "cost")
        show_cost_analysis
        ;;
    "guide")
        show_selection_guide
        ;;
    "optimize")
        show_optimization_tips
        ;;
    "interactive")
        interactive_recommendation
        ;;
    "next")
        show_next_steps
        ;;
    "all"|*)
        show_official_requirements
        show_scale_comparison
        show_cost_analysis
        show_selection_guide
        show_optimization_tips
        echo ""
        echo -e "${BLUE}💭 想要交互式推荐？运行: $0 interactive${NC}"
        echo -e "${BLUE}🚀 查看下一步建议？运行: $0 next${NC}"
        ;;
esac

echo ""
echo -e "${BLUE}================================================================"
echo -e "📚 了解更多，请查看: docs/system-resource-requirements-comparison.md"
echo -e "================================================================"
echo -e "${NC}" 