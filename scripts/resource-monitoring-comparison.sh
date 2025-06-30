#!/bin/bash
# 资源使用实时监控对比脚本

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
echo -e "📊 Knative vs Dapr 资源使用实时监控对比"
echo -e "================================================================"
echo -e "${NC}"

# 检查依赖
check_dependencies() {
    echo -e "${YELLOW}🔍 检查依赖工具...${NC}"
    
    local missing_tools=()
    
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    fi
    
    if ! command -v bc &> /dev/null; then
        missing_tools+=("bc")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        echo -e "${RED}❌ 缺少依赖工具: ${missing_tools[*]}${NC}"
        echo -e "${YELLOW}请安装缺少的工具后重试${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ 依赖检查通过${NC}"
}

# 获取 Pod 资源使用情况
get_pod_resources() {
    local namespace=$1
    local label_selector=$2
    local component_name=$3
    
    kubectl top pods -n $namespace -l $label_selector --no-headers 2>/dev/null | \
    awk -v component="$component_name" '
    {
        cpu_sum += $2
        memory_sum += $3
        count++
    }
    END {
        if (count > 0) {
            printf "%s|%d|%.0f|%.0f\n", component, count, cpu_sum, memory_sum
        } else {
            printf "%s|0|0|0\n", component
        }
    }'
}

# 转换内存单位到 Mi
convert_memory_to_mi() {
    local memory=$1
    if [[ $memory =~ ^([0-9]+)Ki$ ]]; then
        echo "scale=0; ${BASH_REMATCH[1]} / 1024" | bc
    elif [[ $memory =~ ^([0-9]+)Mi$ ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ $memory =~ ^([0-9]+)Gi$ ]]; then
        echo "scale=0; ${BASH_REMATCH[1]} * 1024" | bc
    else
        echo "0"
    fi
}

# 监控 Knative 资源
monitor_knative() {
    echo -e "${CYAN}📊 Knative Eventing 资源使用情况${NC}"
    echo -e "${YELLOW}=================================================${NC}"
    
    # 检查 Knative 是否安装
    if ! kubectl get namespace knative-eventing &> /dev/null; then
        echo -e "${RED}❌ Knative Eventing 未安装${NC}"
        return 1
    fi
    
    # 获取各组件资源使用
    local components=(
        "knative-eventing|app=eventing-controller|Eventing Controller"
        "knative-eventing|app=eventing-webhook|Eventing Webhook"
        "knative-eventing|app=imc-controller|IMC Controller"
        "knative-eventing|app=imc-dispatcher|IMC Dispatcher"
        "knative-eventing|app=mt-broker-ingress|MT Broker Ingress"
        "knative-eventing|app=mt-broker-filter|MT Broker Filter"
    )
    
    local total_cpu=0
    local total_memory=0
    local total_pods=0
    
    printf "%-20s %-8s %-10s %-10s\n" "Component" "Pods" "CPU(m)" "Memory(Mi)"
    printf "%-20s %-8s %-10s %-10s\n" "--------" "----" "-----" "---------"
    
    for component_info in "${components[@]}"; do
        IFS='|' read -r namespace selector name <<< "$component_info"
        local result=$(get_pod_resources $namespace $selector "$name")
        IFS='|' read -r comp_name pod_count cpu memory <<< "$result"
        
        if [ "$pod_count" -gt 0 ]; then
            printf "%-20s %-8s %-10s %-10s\n" "$comp_name" "$pod_count" "$cpu" "$memory"
            total_cpu=$(echo "$total_cpu + $cpu" | bc)
            total_memory=$(echo "$total_memory + $memory" | bc)
            total_pods=$(echo "$total_pods + $pod_count" | bc)
        fi
    done
    
    printf "%-20s %-8s %-10s %-10s\n" "--------" "----" "-----" "---------"
    printf "%-20s %-8s %-10.0f %-10.0f\n" "TOTAL" "$total_pods" "$total_cpu" "$total_memory"
    
    echo ""
    
    # 检查应用 Pod（如果存在）
    local app_pods=$(kubectl get pods --all-namespaces -l '!dapr.io/enabled' --no-headers 2>/dev/null | grep -v "knative\|kube-system\|dapr-system" | wc -l)
    echo -e "应用 Pod 数量: ${GREEN}$app_pods${NC}"
    echo -e "应用额外开销: ${GREEN}0m CPU + 0Mi Memory${NC} (无 Sidecar)"
    
    echo ""
    return 0
}

# 监控 Dapr 资源
monitor_dapr() {
    echo -e "${PURPLE}📊 Dapr 资源使用情况${NC}"
    echo -e "${YELLOW}=================================================${NC}"
    
    # 检查 Dapr 是否安装
    if ! kubectl get namespace dapr-system &> /dev/null; then
        echo -e "${RED}❌ Dapr 未安装${NC}"
        return 1
    fi
    
    # Control Plane 组件
    local components=(
        "dapr-system|app=dapr-operator|Dapr Operator"
        "dapr-system|app=dapr-sidecar-injector|Sidecar Injector"
        "dapr-system|app=dapr-sentry|Dapr Sentry"
        "dapr-system|app=dapr-placement-server|Placement Server"
        "dapr-system|app=dapr-dashboard|Dapr Dashboard"
    )
    
    local total_cpu=0
    local total_memory=0
    local total_pods=0
    
    echo -e "${CYAN}Control Plane:${NC}"
    printf "%-20s %-8s %-10s %-10s\n" "Component" "Pods" "CPU(m)" "Memory(Mi)"
    printf "%-20s %-8s %-10s %-10s\n" "--------" "----" "-----" "---------"
    
    for component_info in "${components[@]}"; do
        IFS='|' read -r namespace selector name <<< "$component_info"
        local result=$(get_pod_resources $namespace $selector "$name")
        IFS='|' read -r comp_name pod_count cpu memory <<< "$result"
        
        if [ "$pod_count" -gt 0 ]; then
            printf "%-20s %-8s %-10s %-10s\n" "$comp_name" "$pod_count" "$cpu" "$memory"
            total_cpu=$(echo "$total_cpu + $cpu" | bc)
            total_memory=$(echo "$total_memory + $memory" | bc)
            total_pods=$(echo "$total_pods + $pod_count" | bc)
        fi
    done
    
    printf "%-20s %-8s %-10s %-10s\n" "--------" "----" "-----" "---------"
    printf "%-20s %-8s %-10.0f %-10.0f\n" "Control Plane Total" "$total_pods" "$total_cpu" "$total_memory"
    
    echo ""
    
    # Sidecar 资源统计
    echo -e "${CYAN}Dapr Sidecars:${NC}"
    local sidecar_pods=$(kubectl get pods --all-namespaces -l 'dapr.io/enabled=true' --no-headers 2>/dev/null | wc -l)
    
    if [ "$sidecar_pods" -gt 0 ]; then
        # 获取 Sidecar 容器资源使用
        local sidecar_stats=$(kubectl get pods --all-namespaces -l 'dapr.io/enabled=true' -o json 2>/dev/null | \
        jq -r '.items[] | select(.status.phase == "Running") | 
               .metadata.namespace + " " + .metadata.name' | \
        while read namespace pod_name; do
            kubectl top pods $pod_name -n $namespace --containers --no-headers 2>/dev/null | grep daprd || echo "daprd 0m 0Mi"
        done)
        
        local sidecar_cpu_total=0
        local sidecar_memory_total=0
        local active_sidecars=0
        
        while IFS= read -r line; do
            if [[ $line =~ daprd[[:space:]]+([0-9]+)m[[:space:]]+([0-9]+)Mi ]]; then
                sidecar_cpu_total=$(echo "$sidecar_cpu_total + ${BASH_REMATCH[1]}" | bc)
                sidecar_memory_total=$(echo "$sidecar_memory_total + ${BASH_REMATCH[2]}" | bc)
                active_sidecars=$((active_sidecars + 1))
            fi
        done <<< "$sidecar_stats"
        
        printf "%-20s %-8s %-10.0f %-10.0f\n" "Dapr Sidecars" "$active_sidecars" "$sidecar_cpu_total" "$sidecar_memory_total"
        
        # 总计
        echo ""
        local grand_total_cpu=$(echo "$total_cpu + $sidecar_cpu_total" | bc)
        local grand_total_memory=$(echo "$total_memory + $sidecar_memory_total" | bc)
        local grand_total_pods=$(echo "$total_pods + $active_sidecars" | bc)
        
        printf "%-20s %-8s %-10s %-10s\n" "--------" "----" "-----" "---------"
        printf "%-20s %-8s %-10.0f %-10.0f\n" "GRAND TOTAL" "$grand_total_pods" "$grand_total_cpu" "$grand_total_memory"
        
        echo ""
        echo -e "应用 Pod 数量: ${GREEN}$active_sidecars${NC}"
        echo -e "平均 Sidecar 开销: ${YELLOW}$(echo "scale=0; $sidecar_cpu_total / $active_sidecars" | bc)m CPU + $(echo "scale=0; $sidecar_memory_total / $active_sidecars" | bc)Mi Memory${NC}"
    else
        echo -e "${YELLOW}⚠️  未发现启用 Dapr 的应用 Pod${NC}"
    fi
    
    echo ""
    return 0
}

# 生成对比报告
generate_comparison_report() {
    echo -e "${BLUE}================================================================"
    echo -e "📈 资源使用对比分析"
    echo -e "================================================================"
    echo -e "${NC}"
    
    # 检查哪个系统在运行
    local knative_running=false
    local dapr_running=false
    
    if kubectl get namespace knative-eventing &> /dev/null; then
        knative_running=true
    fi
    
    if kubectl get namespace dapr-system &> /dev/null; then
        dapr_running=true
    fi
    
    if [ "$knative_running" = true ] && [ "$dapr_running" = true ]; then
        echo -e "${YELLOW}⚠️  检测到 Knative 和 Dapr 同时运行${NC}"
        echo -e "为了准确对比，建议分别测试两个系统"
        echo ""
    fi
    
    # 获取集群总资源
    echo -e "${CYAN}📊 集群资源概览:${NC}"
    local node_count=$(kubectl get nodes --no-headers | wc -l)
    echo -e "节点数量: ${GREEN}$node_count${NC}"
    
    # 计算总 CPU 和内存
    local total_cpu_capacity=$(kubectl get nodes -o json | jq -r '.items[].status.capacity.cpu' | awk '{sum += $1} END {print sum}')
    local total_memory_capacity=$(kubectl get nodes -o json | jq -r '.items[].status.capacity.memory' | sed 's/Ki$//' | awk '{sum += $1} END {printf "%.0f\n", sum/1024/1024}')
    
    echo -e "总 CPU 容量: ${GREEN}${total_cpu_capacity} cores${NC}"
    echo -e "总内存容量: ${GREEN}${total_memory_capacity} Gi${NC}"
    
    echo ""
    
    # 资源利用率建议
    echo -e "${CYAN}💡 资源使用建议:${NC}"
    
    if [ "$knative_running" = true ]; then
        echo -e "✅ Knative 适合:"
        echo -e "   - 大规模服务部署（>50 服务）"
        echo -e "   - 成本敏感的项目"
        echo -e "   - 事件驱动架构"
        echo ""
    fi
    
    if [ "$dapr_running" = true ]; then
        echo -e "✅ Dapr 适合:"
        echo -e "   - 小规模服务部署（<50 服务）"
        echo -e "   - 需要丰富微服务功能"
        echo -e "   - 低延迟要求"
        echo ""
    fi
    
    echo -e "${YELLOW}⚡ 性能优化提示:${NC}"
    echo -e "1. 根据实际负载调整资源限制"
    echo -e "2. 使用 HPA 进行自动扩缩容"
    echo -e "3. 定期监控资源使用趋势"
    echo -e "4. 考虑使用 VPA 进行垂直扩缩容"
}

# 持续监控模式
continuous_monitoring() {
    local interval=${1:-10}
    echo -e "${BLUE}🔄 开始持续监控模式 (间隔: ${interval}s)${NC}"
    echo -e "${YELLOW}按 Ctrl+C 退出${NC}"
    echo ""
    
    while true; do
        clear
        echo -e "${BLUE}📊 实时资源监控 - $(date)${NC}"
        echo ""
        
        monitor_knative
        monitor_dapr
        generate_comparison_report
        
        echo -e "${CYAN}⏰ 下次更新: ${interval}s 后...${NC}"
        sleep $interval
    done
}

# 导出监控数据
export_monitoring_data() {
    local output_file="resource-monitoring-$(date +%Y%m%d-%H%M%S).json"
    
    echo -e "${YELLOW}📋 导出监控数据到: $output_file${NC}"
    
    cat > $output_file << EOF
{
  "timestamp": "$(date -Iseconds)",
  "cluster_info": {
    "nodes": $(kubectl get nodes -o json | jq '.items | length'),
    "total_cpu_capacity": $(kubectl get nodes -o json | jq -r '.items[].status.capacity.cpu' | awk '{sum += $1} END {print sum}'),
    "total_memory_capacity_gi": $(kubectl get nodes -o json | jq -r '.items[].status.capacity.memory' | sed 's/Ki$//' | awk '{sum += $1} END {printf "%.0f\n", sum/1024/1024}')
  },
  "knative": {
    "installed": $(kubectl get namespace knative-eventing &> /dev/null && echo true || echo false),
    "components": $(kubectl top pods -n knative-eventing --no-headers 2>/dev/null | jq -R 'split(" ") | {name: .[0], cpu: .[1], memory: .[2]}' | jq -s '.' || echo '[]')
  },
  "dapr": {
    "installed": $(kubectl get namespace dapr-system &> /dev/null && echo true || echo false),
    "control_plane": $(kubectl top pods -n dapr-system --no-headers 2>/dev/null | jq -R 'split(" ") | {name: .[0], cpu: .[1], memory: .[2]}' | jq -s '.' || echo '[]'),
    "sidecars_enabled_pods": $(kubectl get pods --all-namespaces -l 'dapr.io/enabled=true' --no-headers 2>/dev/null | wc -l)
  }
}
EOF
    
    echo -e "${GREEN}✅ 数据已导出到: $output_file${NC}"
}

# 主程序
case "${1:-}" in
    "monitor")
        check_dependencies
        monitor_knative
        monitor_dapr
        generate_comparison_report
        ;;
    "knative")
        check_dependencies
        monitor_knative
        ;;
    "dapr")
        check_dependencies
        monitor_dapr
        ;;
    "continuous")
        check_dependencies
        continuous_monitoring ${2:-10}
        ;;
    "export")
        check_dependencies
        export_monitoring_data
        ;;
    *)
        echo -e "${BLUE}使用方法：${NC}"
        echo "  $0 monitor      - 一次性监控对比"
        echo "  $0 knative      - 只监控 Knative"
        echo "  $0 dapr         - 只监控 Dapr"
        echo "  $0 continuous [interval] - 持续监控模式"
        echo "  $0 export       - 导出监控数据"
        echo ""
        echo -e "${YELLOW}示例：${NC}"
        echo "  $0 monitor              # 执行一次完整对比"
        echo "  $0 continuous 5         # 每5秒刷新一次"
        echo "  $0 export               # 导出当前数据"
        ;;
esac 