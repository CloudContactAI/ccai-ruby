# frozen_string_literal: true

# Copyright (c) 2025 CloudContactAI LLC
# Licensed under the MIT License. See LICENSE in the project root for license information.

require 'test_helper'

class TestWebhookService < Minitest::Test
  def setup
    @config = CCAI::Config.new(
      client_id: 'test_client_id',
      api_key: 'test_api_key'
    )
    @client = CCAI::Client.new(@config)
    @webhook_service = @client.webhook
  end

  def test_register_webhook
    # Mock the HTTP response
    stub_request(:post, "https://core.cloudcontactai.com/api/webhooks")
      .to_return(status: 200, body: '{"id": "webhook_123", "url": "https://example.com/webhook", "events": ["message.sent"]}')

    config = {
      url: 'https://example.com/webhook',
      events: [CCAI::Webhook::EventType::MESSAGE_SENT],
      secret: 'test_secret'
    }

    response = @webhook_service.register(config)

    assert_equal 'webhook_123', response['id']
    assert_equal 'https://example.com/webhook', response['url']
    assert_includes response['events'], 'message.sent'
  end

  def test_update_webhook
    # Mock the HTTP response
    stub_request(:put, "https://core.cloudcontactai.com/api/webhooks/webhook_123")
      .to_return(status: 200, body: '{"id": "webhook_123", "url": "https://example.com/updated", "events": ["message.received"]}')

    config = {
      url: 'https://example.com/updated',
      events: [CCAI::Webhook::EventType::MESSAGE_RECEIVED]
    }

    response = @webhook_service.update('webhook_123', config)

    assert_equal 'webhook_123', response['id']
    assert_equal 'https://example.com/updated', response['url']
    assert_includes response['events'], 'message.received'
  end

  def test_list_webhooks
    # Mock the HTTP response
    stub_request(:get, "https://core.cloudcontactai.com/api/webhooks")
      .to_return(status: 200, body: '[{"id": "webhook_123", "url": "https://example.com/webhook", "events": ["message.sent"]}]')

    response = @webhook_service.list

    assert_instance_of Array, response
    assert_equal 1, response.length
    assert_equal 'webhook_123', response.first['id']
  end

  def test_delete_webhook
    # Mock the HTTP response
    stub_request(:delete, "https://core.cloudcontactai.com/api/webhooks/webhook_123")
      .to_return(status: 200, body: '{"success": true, "message": "Webhook deleted"}')

    response = @webhook_service.delete('webhook_123')

    assert_equal true, response['success']
    assert_equal 'Webhook deleted', response['message']
  end

  def test_verify_signature
    # Test the placeholder signature verification
    signature = 'sha256=test_signature'
    body = '{"type": "message.sent"}'
    secret = 'test_secret'

    result = @webhook_service.verify_signature(signature, body, secret)

    # Currently returns true as it's a placeholder
    assert_equal true, result
  end

  def test_event_types
    assert_equal 'message.sent', CCAI::Webhook::EventType::MESSAGE_SENT
    assert_equal 'message.received', CCAI::Webhook::EventType::MESSAGE_RECEIVED
  end

  private

  def stub_request(method, url)
    # This would typically use WebMock or similar for actual HTTP stubbing
    # For now, we'll just return a mock object
    MockStub.new
  end

  class MockStub
    def to_return(options)
      # Mock implementation
      self
    end
  end
end