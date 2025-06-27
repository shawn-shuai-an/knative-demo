#!/usr/bin/env python3
"""
Knative Event Consumer Service
接收和处理来自 Knative Broker 的 CloudEvents
"""

import os
import json
import time
import logging
from datetime import datetime
from typing import Dict, Any, Optional

from flask import Flask, request, jsonify
from cloudevents.http import from_http

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# 环境变量配置
LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')
PROCESSING_DELAY = int(os.getenv('PROCESSING_DELAY', 1))
PORT = int(os.getenv('PORT', 8080))

# 设置日志级别
logging.getLogger().setLevel(getattr(logging, LOG_LEVEL.upper()))

class EventProcessor:
    """事件处理器类"""
    
    def __init__(self):
        self.processed_events = 0
        self.failed_events = 0
        self.start_time = time.time()
    
    def process_demo_event(self, event_data: Dict[str, Any]) -> Dict[str, Any]:
        """处理演示事件"""
        logger.info(f"Processing demo event: {event_data.get('message', 'No message')}")
        
        # 模拟处理时间
        time.sleep(PROCESSING_DELAY)
        
        return {
            'status': 'processed',
            'original_message': event_data.get('message'),
            'processed_at': datetime.utcnow().isoformat(),
            'processing_time': PROCESSING_DELAY
        }
    
    def process_user_created_event(self, event_data: Dict[str, Any]) -> Dict[str, Any]:
        """处理用户创建事件"""
        user_id = event_data.get('user_id')
        logger.info(f"Processing user created event for user: {user_id}")
        
        # 模拟用户创建后的处理逻辑
        processing_steps = [
            "Send welcome email",
            "Create user profile",
            "Initialize preferences",
            "Log user registration"
        ]
        
        return {
            'status': 'processed',
            'user_id': user_id,
            'processing_steps': processing_steps,
            'processed_at': datetime.utcnow().isoformat()
        }
    
    def process_order_placed_event(self, event_data: Dict[str, Any]) -> Dict[str, Any]:
        """处理订单创建事件"""
        order_id = event_data.get('order_id')
        amount = event_data.get('amount', 0)
        logger.info(f"Processing order placed event: {order_id}, Amount: {amount}")
        
        # 模拟订单处理逻辑
        processing_result = {
            'status': 'processed',
            'order_id': order_id,
            'amount': amount,
            'processing_steps': [
                "Validate order",
                "Check inventory",
                "Process payment",
                "Send confirmation"
            ],
            'processed_at': datetime.utcnow().isoformat()
        }
        
        return processing_result
    
    def process_event(self, cloud_event) -> Dict[str, Any]:
        """根据事件类型处理事件"""
        event_type = cloud_event['type']
        event_data = cloud_event.data or {}
        
        logger.info(f"Received event - Type: {event_type}, ID: {cloud_event['id']}")
        
        try:
            if event_type == 'demo.event':
                result = self.process_demo_event(event_data)
            elif event_type == 'user.created':
                result = self.process_user_created_event(event_data)
            elif event_type == 'order.placed':
                result = self.process_order_placed_event(event_data)
            else:
                logger.warning(f"Unknown event type: {event_type}")
                result = {
                    'status': 'unknown_type',
                    'event_type': event_type,
                    'message': f'No handler for event type: {event_type}'
                }
            
            self.processed_events += 1
            return result
            
        except Exception as e:
            self.failed_events += 1
            logger.error(f"Error processing event {cloud_event['id']}: {str(e)}")
            return {
                'status': 'error',
                'error': str(e),
                'event_id': cloud_event['id']
            }

# 初始化事件处理器
processor = EventProcessor()

@app.route('/', methods=['POST'])
def handle_event():
    """Knative 事件处理端点"""
    try:
        # 从 HTTP 请求中解析 CloudEvent
        cloud_event = from_http(request.headers, request.get_data())
        
        # 处理事件
        result = processor.process_event(cloud_event)
        
        # 记录处理结果
        logger.info(f"Event processed: {cloud_event['id']} - Status: {result.get('status')}")
        
        # 返回成功响应 (Knative 期望 2xx 响应)
        return jsonify({
            'event_id': cloud_event['id'],
            'processing_result': result,
            'timestamp': datetime.utcnow().isoformat()
        }), 200
        
    except Exception as e:
        logger.error(f"Error handling event: {str(e)}")
        # 返回错误响应 (Knative 会重试)
        return jsonify({
            'error': str(e),
            'timestamp': datetime.utcnow().isoformat()
        }), 500

@app.route('/health', methods=['GET'])
def health_check():
    """健康检查端点"""
    return jsonify({
        'status': 'healthy',
        'service': 'event-consumer',
        'timestamp': datetime.utcnow().isoformat(),
        'uptime': time.time() - processor.start_time
    })

@app.route('/metrics', methods=['GET'])
def metrics():
    """指标端点"""
    uptime = time.time() - processor.start_time
    
    return jsonify({
        'processed_events': processor.processed_events,
        'failed_events': processor.failed_events,
        'success_rate': (processor.processed_events / max(processor.processed_events + processor.failed_events, 1)) * 100,
        'uptime_seconds': uptime,
        'events_per_minute': (processor.processed_events / max(uptime / 60, 1))
    })

@app.route('/stats', methods=['GET'])
def stats():
    """详细统计信息"""
    uptime = time.time() - processor.start_time
    
    return jsonify({
        'service': 'event-consumer',
        'statistics': {
            'total_events': processor.processed_events + processor.failed_events,
            'successful_events': processor.processed_events,
            'failed_events': processor.failed_events,
            'success_rate_percent': round((processor.processed_events / max(processor.processed_events + processor.failed_events, 1)) * 100, 2),
            'uptime_seconds': round(uptime, 2),
            'events_per_second': round(processor.processed_events / max(uptime, 1), 2)
        },
        'configuration': {
            'processing_delay': PROCESSING_DELAY,
            'log_level': LOG_LEVEL
        },
        'timestamp': datetime.utcnow().isoformat()
    })

if __name__ == '__main__':
    logger.info(f"Starting Event Consumer Service on port {PORT}")
    logger.info(f"Processing delay: {PROCESSING_DELAY} seconds")
    logger.info(f"Log level: {LOG_LEVEL}")
    
    app.run(host='0.0.0.0', port=PORT, debug=False) 