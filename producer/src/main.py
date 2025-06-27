#!/usr/bin/env python3
"""
Knative Event Producer Service
生成 CloudEvents 格式的事件并发送到 Knative Broker
"""

import os
import json
import time
import uuid
import logging
from datetime import datetime
from typing import Dict, Any

from flask import Flask, request, jsonify
import requests
from cloudevents.http import CloudEvent, to_structured

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# 环境变量配置
BROKER_URL = os.getenv('BROKER_URL', 'http://broker-ingress.knative-eventing.svc.cluster.local/knative-demo/default')
EVENT_TYPE = os.getenv('EVENT_TYPE', 'demo.event')
SOURCE = os.getenv('SOURCE', 'knative-demo-producer')
PORT = int(os.getenv('PORT', 8080))

class EventProducer:
    """事件生产者类"""
    
    def __init__(self, broker_url: str, source: str):
        self.broker_url = broker_url
        self.source = source
        self.event_counter = 0
    
    def create_event(self, event_type: str, data: Dict[str, Any]) -> CloudEvent:
        """创建 CloudEvent"""
        self.event_counter += 1
        
        attributes = {
            "type": event_type,
            "source": self.source,
            "id": str(uuid.uuid4()),
            "time": datetime.utcnow().isoformat() + "Z",
            "datacontenttype": "application/json"
        }
        
        event = CloudEvent(attributes, data)
        return event
    
    def send_event(self, event: CloudEvent) -> bool:
        """发送事件到 Broker"""
        try:
            headers, body = to_structured(event)
            
            response = requests.post(
                self.broker_url,
                headers=headers,
                data=body,
                timeout=10
            )
            
            if response.status_code == 202:
                logger.info(f"Event sent successfully: {event['id']}")
                return True
            else:
                logger.error(f"Failed to send event: {response.status_code} - {response.text}")
                return False
                
        except Exception as e:
            logger.error(f"Error sending event: {str(e)}")
            return False

# 初始化事件生产者
producer = EventProducer(BROKER_URL, SOURCE)

@app.route('/health', methods=['GET'])
def health_check():
    """健康检查端点"""
    return jsonify({
        'status': 'healthy',
        'service': 'event-producer',
        'timestamp': datetime.utcnow().isoformat()
    })

@app.route('/produce', methods=['POST'])
def produce_event():
    """手动生成事件端点"""
    try:
        request_data = request.get_json() or {}
        
        # 构建事件数据
        event_data = {
            'message': request_data.get('message', 'Hello from Knative Producer!'),
            'timestamp': datetime.utcnow().isoformat(),
            'counter': producer.event_counter + 1,
            'metadata': request_data.get('metadata', {})
        }
        
        # 创建和发送事件
        event_type = request_data.get('type', EVENT_TYPE)
        event = producer.create_event(event_type, event_data)
        
        success = producer.send_event(event)
        
        if success:
            return jsonify({
                'status': 'success',
                'event_id': event['id'],
                'event_type': event_type,
                'data': event_data
            }), 200
        else:
            return jsonify({
                'status': 'error',
                'message': 'Failed to send event'
            }), 500
            
    except Exception as e:
        logger.error(f"Error in produce_event: {str(e)}")
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@app.route('/produce/batch', methods=['POST'])
def produce_batch_events():
    """批量生成事件端点"""
    try:
        request_data = request.get_json() or {}
        count = request_data.get('count', 5)
        event_type = request_data.get('type', EVENT_TYPE)
        
        results = []
        for i in range(count):
            event_data = {
                'message': f'Batch event {i+1} of {count}',
                'timestamp': datetime.utcnow().isoformat(),
                'counter': producer.event_counter + 1,
                'batch_id': str(uuid.uuid4()),
                'index': i + 1,
                'total': count
            }
            
            event = producer.create_event(event_type, event_data)
            success = producer.send_event(event)
            
            results.append({
                'event_id': event['id'],
                'success': success
            })
            
            # 小延迟避免过载
            time.sleep(0.1)
        
        successful_events = sum(1 for r in results if r['success'])
        
        return jsonify({
            'status': 'completed',
            'total_events': count,
            'successful_events': successful_events,
            'failed_events': count - successful_events,
            'results': results
        }), 200
        
    except Exception as e:
        logger.error(f"Error in produce_batch_events: {str(e)}")
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@app.route('/metrics', methods=['GET'])
def metrics():
    """简单的指标端点"""
    return jsonify({
        'events_produced': producer.event_counter,
        'broker_url': producer.broker_url,
        'source': producer.source,
        'uptime': time.time()
    })

if __name__ == '__main__':
    logger.info(f"Starting Event Producer Service on port {PORT}")
    logger.info(f"Broker URL: {BROKER_URL}")
    logger.info(f"Event Source: {SOURCE}")
    
    app.run(host='0.0.0.0', port=PORT, debug=False) 