# frozen_string_literal: true

# Copyright (c) 2025 CloudContactAI LLC
# Licensed under the MIT License. See LICENSE in the project root for license information.

require 'test_helper'

class TestClient < Minitest::Test
  def setup
    @client_id = 'test-client-id'
    @api_key = 'test-api-key'
    @base_url = 'https://test-api.example.com'
  end

  def test_new_client_with_valid_config
    client = CCAI.new(client_id: @client_id, api_key: @api_key, base_url: @base_url)
    assert_equal @client_id, client.client_id
    assert_equal @api_key, client.api_key
    assert_equal @base_url, client.base_url
  end

  def test_new_client_with_default_base_url
    client = CCAI.new(client_id: @client_id, api_key: @api_key)
    assert_equal 'https://core.cloudcontactai.com/api', client.base_url
  end

  def test_new_client_with_empty_client_id
    assert_raises ArgumentError do
      CCAI.new(client_id: '', api_key: @api_key)
    end
  end

  def test_new_client_with_empty_api_key
    assert_raises ArgumentError do
      CCAI.new(client_id: @client_id, api_key: '')
    end
  end

  def test_client_services
    client = CCAI.new(client_id: @client_id, api_key: @api_key)
    assert_instance_of CCAI::SMS::SMSService, client.sms
    assert_instance_of CCAI::SMS::MMSService, client.mms
  end

  def test_request_success
    client = CCAI.new(client_id: @client_id, api_key: @api_key)
    
    stub_request(:get, "#{client.base_url}/test-endpoint")
      .with(
        headers: {
          'Authorization' => "Bearer #{@api_key}",
          'Content-Type' => 'application/json',
          'Accept' => '*/*'
        }
      )
      .to_return(
        status: 200,
        body: '{"id":"test-id","status":"success"}',
        headers: { 'Content-Type' => 'application/json' }
      )
    
    response = client.request(:get, '/test-endpoint')
    assert_equal 'test-id', response['id']
    assert_equal 'success', response['status']
  end

  def test_request_with_data
    client = CCAI.new(client_id: @client_id, api_key: @api_key)
    
    stub_request(:post, "#{client.base_url}/test-endpoint")
      .with(
        body: '{"test":"data"}',
        headers: {
          'Authorization' => "Bearer #{@api_key}",
          'Content-Type' => 'application/json',
          'Accept' => '*/*'
        }
      )
      .to_return(
        status: 200,
        body: '{"id":"test-id","status":"success"}',
        headers: { 'Content-Type' => 'application/json' }
      )
    
    response = client.request(:post, '/test-endpoint', { test: 'data' })
    assert_equal 'test-id', response['id']
    assert_equal 'success', response['status']
  end

  def test_request_with_headers
    client = CCAI.new(client_id: @client_id, api_key: @api_key)
    
    stub_request(:post, "#{client.base_url}/test-endpoint")
      .with(
        body: '{"test":"data"}',
        headers: {
          'Authorization' => "Bearer #{@api_key}",
          'Content-Type' => 'application/json',
          'Accept' => '*/*',
          'Custom-Header' => 'custom-value'
        }
      )
      .to_return(
        status: 200,
        body: '{"id":"test-id","status":"success"}',
        headers: { 'Content-Type' => 'application/json' }
      )
    
    response = client.request(:post, '/test-endpoint', { test: 'data' }, { 'Custom-Header' => 'custom-value' })
    assert_equal 'test-id', response['id']
    assert_equal 'success', response['status']
  end

  def test_request_error
    client = CCAI.new(client_id: @client_id, api_key: @api_key)
    
    stub_request(:get, "#{client.base_url}/test-endpoint")
      .to_return(
        status: 400,
        body: '{"error":"Bad request"}',
        headers: { 'Content-Type' => 'application/json' }
      )
    
    assert_raises CCAI::Error do
      client.request(:get, '/test-endpoint')
    end
  end
end
