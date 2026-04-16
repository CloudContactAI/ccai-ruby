# frozen_string_literal: true

# Copyright (c) 2025 CloudContactAI LLC
# Licensed under the MIT License. See LICENSE in the project root for license information.

require 'test_helper'
require 'base64'

class TestWebhookService < Minitest::Test
  def setup
    @config = CCAI::Config.new(
      client_id: 'test_client_id',
      api_key: 'test_api_key'
    )
    @client = CCAI::Client.new(@config)
    @webhook_service = @client.webhook
  end

  def test_register_webhook_auto_generated_secret
    stub_request(:post, "https://core.cloudcontactai.com/api/v1/client/test_client_id/integration")
      .to_return(
        status: 200,
        body: '[{"id": "webhook_123", "url": "https://example.com/webhook", "method": "POST", "integrationType": "ALL", "secretKey": "sk_live_auto_generated"}]',
        headers: { 'Content-Type' => 'application/json' }
      )

    config = {
      url: 'https://example.com/webhook'
      # secret not provided - server should auto-generate
    }

    response = @webhook_service.register(config)

    assert_equal 'webhook_123', response['id']
    assert_equal 'https://example.com/webhook', response['url']
    assert_equal 'sk_live_auto_generated', response['secretKey']
  end

  def test_register_webhook_custom_secret
    stub_request(:post, "https://core.cloudcontactai.com/api/v1/client/test_client_id/integration")
      .to_return(
        status: 200,
        body: '[{"id": "webhook_124", "url": "https://example.com/webhook-custom", "method": "POST", "integrationType": "ALL", "secretKey": "my-custom-secret"}]',
        headers: { 'Content-Type' => 'application/json' }
      )

    config = {
      url: 'https://example.com/webhook-custom',
      secret: 'my-custom-secret'
    }

    response = @webhook_service.register(config)

    assert_equal 'webhook_124', response['id']
    assert_equal 'my-custom-secret', response['secretKey']
  end

  def test_update_webhook_without_secret
    stub_request(:post, "https://core.cloudcontactai.com/api/v1/client/test_client_id/integration")
      .to_return(
        status: 200,
        body: '[{"id": "webhook_123", "url": "https://example.com/updated", "method": "POST", "integrationType": "ALL"}]',
        headers: { 'Content-Type' => 'application/json' }
      )

    config = {
      url: 'https://example.com/updated'
      # secret not provided - server will keep existing secret
    }

    response = @webhook_service.update('webhook_123', config)

    assert_equal 'webhook_123', response['id']
    assert_equal 'https://example.com/updated', response['url']
  end

  def test_update_webhook_with_secret
    stub_request(:post, "https://core.cloudcontactai.com/api/v1/client/test_client_id/integration")
      .to_return(
        status: 200,
        body: '[{"id": "webhook_123", "url": "https://example.com/updated", "method": "POST", "integrationType": "ALL", "secretKey": "new_secret"}]',
        headers: { 'Content-Type' => 'application/json' }
      )

    config = {
      url: 'https://example.com/updated',
      secret: 'new_secret'
    }

    response = @webhook_service.update('webhook_123', config)

    assert_equal 'webhook_123', response['id']
    assert_equal 'new_secret', response['secretKey']
  end

  def test_list_webhooks
    stub_request(:get, "https://core.cloudcontactai.com/api/v1/client/test_client_id/integration")
      .to_return(
        status: 200,
        body: '[{"id": "webhook_123", "url": "https://example.com/webhook", "method": "POST"}]',
        headers: { 'Content-Type' => 'application/json' }
      )

    response = @webhook_service.list

    assert_instance_of Array, response
    assert_equal 1, response.length
    assert_equal 'webhook_123', response.first['id']
  end

  def test_delete_webhook
    stub_request(:delete, "https://core.cloudcontactai.com/api/v1/client/test_client_id/integration/webhook_123")
      .to_return(
        status: 200,
        body: '{"success": true, "message": "Webhook deleted"}',
        headers: { 'Content-Type' => 'application/json' }
      )

    response = @webhook_service.delete('webhook_123')

    assert_equal true, response['success']
    assert_equal 'Webhook deleted', response['message']
  end

  def test_verify_signature_valid
    client_id = 'test_client_id'
    event_hash = 'event_hash_abc123'
    secret = 'test_secret'

    # Compute expected signature: HMAC-SHA256(secretKey, clientId:eventHash) in Base64
    data = "#{client_id}:#{event_hash}"
    computed = OpenSSL::HMAC.digest('SHA256', secret, data)
    valid_sig = Base64.strict_encode64(computed)

    result = @webhook_service.verify_signature(valid_sig, client_id, event_hash, secret)
    assert result
  end

  def test_verify_signature_invalid
    client_id = 'test_client_id'
    event_hash = 'event_hash_abc123'
    secret = 'test_secret'

    result = @webhook_service.verify_signature('bad_signature', client_id, event_hash, secret)
    refute result
  end

  def test_verify_signature_missing_params
    refute @webhook_service.verify_signature(nil, 'client_id', 'event_hash', 'secret')
    refute @webhook_service.verify_signature('sig', nil, 'event_hash', 'secret')
    refute @webhook_service.verify_signature('sig', 'client_id', nil, 'secret')
    refute @webhook_service.verify_signature('sig', 'client_id', 'event_hash', nil)
  end

  def test_parse_event
    json = '{"type":"message.sent","id":"msg-123","phone":"+15551234567"}'
    event = @webhook_service.parse_event(json)

    assert_equal 'message.sent', event['type']
    assert_equal 'msg-123', event['id']
    assert_equal '+15551234567', event['phone']
  end

  def test_parse_event_invalid_json
    assert_raises CCAI::Error do
      @webhook_service.parse_event('not valid json')
    end
  end

  def test_process_payload
    payload = { 'type' => 'message.sent', 'campaign' => 'camp-1', 'from' => '+15551111', 'to' => '+15552222', 'message' => 'Hello' }
    result = @webhook_service.process_payload(payload)

    assert_instance_of CCAI::Webhook::WebhookPayload, result
    assert result.message_sent?
  end

  def test_event_types
    assert_equal 'message.sent', CCAI::Webhook::EventType::MESSAGE_SENT
    assert_equal 'message.received', CCAI::Webhook::EventType::MESSAGE_RECEIVED
  end
end
