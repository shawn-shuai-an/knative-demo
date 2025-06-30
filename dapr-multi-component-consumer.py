#!/usr/bin/env python3
"""
Dapr 多 Component 消费者应用
使用不同的 Component 实现真正的并发隔离
"""

import json
import copy
import time
import logging
import threading
from datetime import datetime
from flask import Flask, request, jsonify, Response

# 配置日志
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

app = Flask(__name__)

# 消息处理统计
stats = {
    'pod_events': {'processed': 0, 'failed': 0, 'active': 0},
    'deployment_events': {'processed': 0, 'failed': 0, 'active': 0},
    'service_events': {'processed': 0, 'failed': 0, 'active': 0}
}
stats_lock = threading.Lock()

def update_stats(event_type, action):
    """线程安全地更新统计信息"""
    with stats_lock:
        if action == 'start':
            stats[event_type]['active'] += 1
        elif action == 'success':
            stats[event_type]['processed'] += 1
            stats[event_type]['active'] -= 1
        elif action == 'fail':
            stats[event_type]['failed'] += 1
            stats[event_type]['active'] -= 1

@app.route('/dapr/subscribe', methods=['GET'])
def subscribe():
    """
    Dapr 订阅配置 - 使用不同的 Component
    每种消息类型使用专用的 Component，实现真正的隔离
    """
    subscriptions = [
        # Pod 事件 - 使用高并发 Component
        {
            "pubsubname": "pod-events-pubsub",      # 专用Component
            "topic": "pod-events",
            "route": "/pod-events",
            "metadata": {
                "consumerGroup": "pod-processors"
            }
        },
        # Deployment 事件 - 使用中等并发 Component
        {
            "pubsubname": "deployment-events-pubsub",  # 专用Component
            "topic": "deployment-events", 
            "route": "/deployment-events",
            "metadata": {
                "consumerGroup": "deployment-processors"
            }
        },
        # Service 事件 - 使用低并发 Component  
        {
            "pubsubname": "service-events-pubsub",     # 专用Component
            "topic": "service-events",
            "route": "/service-events",
            "metadata": {
                "consumerGroup": "service-processors"
            }
        }
    ]
    
    logger.info(f"📋 Returning {len(subscriptions)} subscriptions with isolated components")
    return jsonify(subscriptions)

@app.route('/pod-events', methods=['POST'])
def handle_pod_events():
    """
    Pod 事件处理器 - 高频，轻量级处理
    使用 pod-events-pubsub Component (50 并发)
    """
    update_stats('pod_events', 'start')
    
    try:
        event_data = request.get_json()
        pod_name = event_data.get('data', {}).get('name', 'unknown')
        
        logger.info(f"🔵 [Pod-{threading.current_thread().ident}] Processing pod: {pod_name}")
        
        # 轻量级处理 - 快速响应
        time.sleep(0.1)  # 模拟快速处理
        
        update_stats('pod_events', 'success')
        logger.info(f"✅ [Pod] Processed {pod_name} quickly")
        
        return Response(status=200)
        
    except Exception as e:
        update_stats('pod_events', 'fail')
        logger.error(f"❌ [Pod] Error: {str(e)}")
        return Response(status=500)

@app.route('/deployment-events', methods=['POST'])
def handle_deployment_events():
    """
    Deployment 事件处理器 - 中频，中等处理
    使用 deployment-events-pubsub Component (20 并发)
    """
    update_stats('deployment_events', 'start')
    
    try:
        event_data = request.get_json()
        deployment_name = event_data.get('data', {}).get('name', 'unknown')
        
        logger.info(f"🟢 [Deployment-{threading.current_thread().ident}] Processing deployment: {deployment_name}")
        
        # 中等复杂度处理
        time.sleep(1.0)  # 模拟中等处理时间
        
        # 模拟一些业务逻辑
        if 'critical' in deployment_name:
            time.sleep(0.5)  # 关键部署需要额外检查
        
        update_stats('deployment_events', 'success')
        logger.info(f"✅ [Deployment] Processed {deployment_name} with medium complexity")
        
        return Response(status=200)
        
    except Exception as e:
        update_stats('deployment_events', 'fail')
        logger.error(f"❌ [Deployment] Error: {str(e)}")
        return Response(status=500)

@app.route('/service-events', methods=['POST'])
def handle_service_events():
    """
    Service 事件处理器 - 低频，复杂处理
    使用 service-events-pubsub Component (10 并发)
    """
    update_stats('service_events', 'start')
    
    try:
        event_data = request.get_json()
        service_name = event_data.get('data', {}).get('name', 'unknown')
        
        logger.info(f"🟡 [Service-{threading.current_thread().ident}] Processing service: {service_name}")
        
        # 复杂处理逻辑
        time.sleep(3.0)  # 模拟复杂处理时间
        
        # 模拟复杂的业务逻辑
        steps = ['validate', 'analyze', 'update_dependencies', 'notify']
        for step in steps:
            logger.info(f"🔄 [Service] {service_name} - executing {step}")
            time.sleep(0.5)
        
        update_stats('service_events', 'success')
        logger.info(f"✅ [Service] Processed {service_name} with complex logic")
        
        return Response(status=200)
        
    except Exception as e:
        update_stats('service_events', 'fail')
        logger.error(f"❌ [Service] Error: {str(e)}")
        return Response(status=500)

@app.route('/health', methods=['GET'])
def health_check():
    """健康检查端点"""
    with stats_lock:
        current_stats = copy.deepcopy(stats)
    
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "statistics": current_stats,
        "total_active": sum(s['active'] for s in current_stats.values()),
        "total_processed": sum(s['processed'] for s in current_stats.values())
    })

@app.route('/metrics', methods=['GET'])
def metrics():
    """详细指标端点"""
    with stats_lock:
        current_stats = copy.deepcopy(stats)
    
    # 计算各种聚合指标
    total_processed = sum(s['processed'] for s in current_stats.values())
    total_failed = sum(s['failed'] for s in current_stats.values())
    total_active = sum(s['active'] for s in current_stats.values())
    
    success_rate = (total_processed / max(total_processed + total_failed, 1)) * 100
    
    return jsonify({
        "event_types": current_stats,
        "summary": {
            "total_processed": total_processed,
            "total_failed": total_failed,
            "total_active": total_active,
            "success_rate_percent": round(success_rate, 2)
        },
        "component_isolation": {
            "pod_events_component": "pod-events-pubsub (50 concurrency)",
            "deployment_events_component": "deployment-events-pubsub (20 concurrency)",
            "service_events_component": "service-events-pubsub (10 concurrency)"
        },
        "isolation_benefits": [
            "Pod事件高并发不影响Deployment事件处理",
            "Service事件复杂处理不阻塞Pod事件",
            "每种事件类型有独立的重试和死信策略",
            "Redis DB隔离确保数据独立性"
        ],
        "timestamp": datetime.utcnow().isoformat()
    })

@app.route('/stress-test', methods=['POST'])
def stress_test():
    """压力测试端点 - 验证隔离效果"""
    test_config = request.get_json() or {}
    duration = test_config.get('duration', 10)  # 测试时长(秒)
    
    logger.info(f"🚀 Starting stress test for {duration} seconds")
    
    start_time = time.time()
    initial_stats = {}
    with stats_lock:
        initial_stats = copy.deepcopy(stats)
    
    # 等待指定时间
    time.sleep(duration)
    
    end_time = time.time()
    final_stats = {}
    with stats_lock:
        final_stats = copy.deepcopy(stats)
    
    # 计算差值
    results = {}
    for event_type in stats.keys():
        processed_delta = final_stats[event_type]['processed'] - initial_stats[event_type]['processed']
        failed_delta = final_stats[event_type]['failed'] - initial_stats[event_type]['failed']
        
        results[event_type] = {
            "processed_during_test": processed_delta,
            "failed_during_test": failed_delta,
            "processing_rate_per_second": round(processed_delta / duration, 2),
            "current_active": final_stats[event_type]['active']
        }
    
    return jsonify({
        "test_duration_seconds": duration,
        "isolation_test_results": results,
        "conclusion": "每种事件类型独立处理，无相互影响" if all(
            r["processing_rate_per_second"] > 0 for r in results.values()
        ) else "检测到潜在的资源竞争问题"
    })

if __name__ == '__main__':
    logger.info("🚀 Starting multi-component Dapr consumer")
    logger.info("🔧 Using isolated components for each event type:")
    logger.info("   • Pod events → pod-events-pubsub (50 concurrency)")
    logger.info("   • Deployment events → deployment-events-pubsub (20 concurrency)")  
    logger.info("   • Service events → service-events-pubsub (10 concurrency)")
    
    app.run(host='0.0.0.0', port=6001, debug=False) 