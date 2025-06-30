#!/usr/bin/env python3
"""
Dapr Redis 重试机制示例应用
演示消息处理失败时的自动重试行为
"""

import json
import time
import random
import logging
from datetime import datetime
from flask import Flask, request, jsonify, Response
from dapr.clients import DaprClient

# 配置日志
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

app = Flask(__name__)

# 模拟失败率（用于测试重试机制）
FAILURE_RATE = 0.3  # 30% 的消息会失败
processed_count = 0
failed_count = 0
retry_count = 0

class MessageProcessor:
    def __init__(self):
        self.processed_messages = set()  # 防重复处理
        
    def process_message(self, message_data):
        """
        业务消息处理逻辑
        返回: (success: bool, should_retry: bool)
        """
        global processed_count, failed_count, retry_count
        
        message_id = message_data.get('id', 'unknown')
        message_content = message_data.get('message', '')
        
        # 检查是否已处理过（幂等性保证）
        if message_id in self.processed_messages:
            logger.warning(f"💡 Message {message_id} already processed, skipping")
            return True, False
        
        logger.info(f"🔄 Processing message: {message_id} - {message_content}")
        
        # 模拟业务处理
        try:
            # 模拟随机失败（用于测试重试）
            if random.random() < FAILURE_RATE:
                failed_count += 1
                logger.error(f"❌ Processing failed for message {message_id}")
                
                # 根据失败类型决定是否重试
                failure_type = random.choice(['transient', 'permanent'])
                if failure_type == 'transient':
                    # 暂时性错误，应该重试
                    retry_count += 1
                    logger.info(f"🔁 Transient error, requesting retry for {message_id}")
                    return False, True
                else:
                    # 永久性错误，不应该重试
                    logger.error(f"💀 Permanent error, no retry for {message_id}")
                    return False, False
            
            # 模拟处理时间
            time.sleep(random.uniform(0.1, 0.5))
            
            # 处理成功
            self.processed_messages.add(message_id)
            processed_count += 1
            logger.info(f"✅ Successfully processed message {message_id}")
            return True, False
            
        except Exception as e:
            failed_count += 1
            logger.error(f"💥 Unexpected error processing {message_id}: {str(e)}")
            return False, True  # 未知错误，尝试重试

# 创建消息处理器实例
processor = MessageProcessor()

@app.route('/dapr/subscribe', methods=['GET'])
def subscribe():
    """Dapr 订阅端点配置"""
    subscriptions = [
        {
            "pubsubname": "pubsub-with-retry",
            "topic": "test-events",
            "route": "/events",
            "metadata": {
                "consumerGroup": "retry-test-group"
            }
        },
        {
            "pubsubname": "deadletter-handler", 
            "topic": "deadletter-topic",
            "route": "/deadletter",
            "metadata": {
                "consumerGroup": "deadletter-group"
            }
        }
    ]
    logger.info(f"📋 Returning subscriptions: {subscriptions}")
    return jsonify(subscriptions)

@app.route('/events', methods=['POST'])
def handle_events():
    """主要的事件处理端点"""
    try:
        # 获取消息数据
        event_data = request.get_json()
        logger.info(f"📨 Received event: {json.dumps(event_data, indent=2)}")
        
        # 处理消息
        success, should_retry = processor.process_message(event_data.get('data', {}))
        
        if success:
            # 处理成功，返回 200
            return Response(status=200)
        elif should_retry:
            # 处理失败但应该重试，返回 500 让 Dapr 重试
            logger.warning(f"🔁 Returning 500 to trigger Dapr retry")
            return Response(status=500)
        else:
            # 处理失败且不应该重试，返回 200 避免重试
            logger.error(f"💀 Permanent failure, returning 200 to stop retries")
            return Response(status=200)
            
    except Exception as e:
        logger.error(f"💥 Error in event handler: {str(e)}")
        # 未知错误，让 Dapr 重试
        return Response(status=500)

@app.route('/deadletter', methods=['POST'])
def handle_deadletter():
    """死信队列处理端点"""
    try:
        event_data = request.get_json()
        message_id = event_data.get('data', {}).get('id', 'unknown')
        
        logger.error(f"💀 Processing dead letter message: {message_id}")
        logger.error(f"💀 Dead letter data: {json.dumps(event_data, indent=2)}")
        
        # 死信处理逻辑：
        # 1. 记录到数据库
        # 2. 发送告警通知
        # 3. 人工处理队列
        # 4. 数据修复
        
        # 这里可以实现具体的死信处理逻辑
        handle_dead_letter_message(event_data)
        
        return Response(status=200)
        
    except Exception as e:
        logger.error(f"💥 Error in deadletter handler: {str(e)}")
        return Response(status=500)

def handle_dead_letter_message(event_data):
    """死信消息处理逻辑"""
    # 实现具体的死信处理
    # 例如：保存到特殊表、发送告警等
    pass

@app.route('/health', methods=['GET'])
def health_check():
    """健康检查端点"""
    return jsonify({
        "status": "healthy",
        "processed_count": processed_count,
        "failed_count": failed_count,
        "retry_count": retry_count,
        "success_rate": round((processed_count / max(processed_count + failed_count, 1)) * 100, 2)
    })

@app.route('/metrics', methods=['GET'])
def metrics():
    """指标端点"""
    return jsonify({
        "processed_messages": processed_count,
        "failed_messages": failed_count,
        "retry_attempts": retry_count,
        "success_rate_percent": round((processed_count / max(processed_count + failed_count, 1)) * 100, 2),
        "unique_processed": len(processor.processed_messages),
        "timestamp": datetime.utcnow().isoformat()
    })

@app.route('/test-publish', methods=['POST'])
def test_publish():
    """测试消息发布端点"""
    try:
        with DaprClient() as client:
            for i in range(5):
                message = {
                    "id": f"test-msg-{int(time.time())}-{i}",
                    "message": f"Test message {i}",
                    "timestamp": datetime.utcnow().isoformat(),
                    "source": "test-publisher"
                }
                
                client.publish_event(
                    pubsub_name="pubsub-with-retry",
                    topic_name="test-events", 
                    data=json.dumps(message),
                    data_content_type='application/json'
                )
                
                logger.info(f"📤 Published test message {i}")
                time.sleep(0.1)
        
        return jsonify({"status": "Published 5 test messages"})
        
    except Exception as e:
        logger.error(f"💥 Error publishing test messages: {str(e)}")
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    logger.info("🚀 Starting Dapr retry demo consumer")
    logger.info(f"💀 Simulated failure rate: {FAILURE_RATE * 100}%")
    app.run(host='0.0.0.0', port=6001, debug=False) 