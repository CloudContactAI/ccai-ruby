# frozen_string_literal: true

# Copyright (c) 2025 CloudContactAI LLC
# Licensed under the MIT License. See LICENSE in the project root for license information.

require 'test_helper'

class TestSMSService < Minitest::Test
  def setup
    @client_id = 'test-client-id'
    @api_key = 'test-api-key'
    @client = CCAI.new(client_id: @client_id, api_key: @api_key)
    
    @account = CCAI::SMS::Account.new(
      first_name: 'John',
      last_name: 'Doe',
      phone: '+15551234567'
    )
    
    @message = 'Hello ${firstName}, this is a test message!'
    @title = 'Test Campaign'
  end

  def test_send_with_valid_inputs
    stub_request(:post, "#{@client.base_url}/clients/#{@client_id}/campaigns/direct")
      .with(
        body: {
          accounts: [
            {
              firstName: 'John',
              lastName: 'Doe',
              phone: '+15551234567'
            }
          ],
          message: @message,
          title: @title
        }.to_json,
        headers: {
          'Authorization' => "Bearer #{@api_key}",
          'Content-Type' => 'application/json',
          'Accept' => '*/*'
        }
      )
      .to_return(
        status: 200,
        body: {
          id: 'msg-123',
          status: 'sent',
          campaignId: 'camp-456',
          messagesSent: 1,
          timestamp: '2025-06-06T12:00:00Z'
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    
    response = @client.sms.send([@account], @message, @title)
    
    assert_equal 'msg-123', response.id
    assert_equal 'sent', response.status
    assert_equal 'camp-456', response.campaign_id
    assert_equal 1, response.messages_sent
    assert_equal '2025-06-06T12:00:00Z', response.timestamp
  end

  def test_send_with_empty_accounts
    assert_raises ArgumentError do
      @client.sms.send([], @message, @title)
    end
  end

  def test_send_with_empty_message
    assert_raises ArgumentError do
      @client.sms.send([@account], '', @title)
    end
  end

  def test_send_with_empty_title
    assert_raises ArgumentError do
      @client.sms.send([@account], @message, '')
    end
  end

  def test_send_with_progress_tracking
    stub_request(:post, "#{@client.base_url}/clients/#{@client_id}/campaigns/direct")
      .to_return(
        status: 200,
        body: { id: 'msg-123', status: 'sent' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    
    progress_updates = []
    options = CCAI::SMS::Options.new(
      on_progress: ->(status) { progress_updates << status }
    )
    
    @client.sms.send([@account], @message, @title, options)
    
    assert_equal 3, progress_updates.size
    assert_equal 'Preparing to send SMS', progress_updates[0]
    assert_equal 'Sending SMS', progress_updates[1]
    assert_equal 'SMS sent successfully', progress_updates[2]
  end

  def test_send_with_api_error
    stub_request(:post, "#{@client.base_url}/clients/#{@client_id}/campaigns/direct")
      .to_return(
        status: 400,
        body: { error: 'Bad request' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    
    progress_updates = []
    options = CCAI::SMS::Options.new(
      on_progress: ->(status) { progress_updates << status }
    )
    
    assert_raises CCAI::Error do
      @client.sms.send([@account], @message, @title, options)
    end
    
    assert_equal 2, progress_updates.size
    assert_equal 'Preparing to send SMS', progress_updates[0]
    assert_equal 'SMS sending failed', progress_updates[1]
  end

  def test_send_single
    stub_request(:post, "#{@client.base_url}/clients/#{@client_id}/campaigns/direct")
      .with(
        body: {
          accounts: [
            {
              firstName: 'Jane',
              lastName: 'Smith',
              phone: '+15559876543'
            }
          ],
          message: 'Hi ${firstName}, thanks for your interest!',
          title: 'Single Message Test'
        }.to_json
      )
      .to_return(
        status: 200,
        body: { id: 'msg-123', status: 'sent' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    
    response = @client.sms.send_single(
      'Jane',
      'Smith',
      '+15559876543',
      'Hi ${firstName}, thanks for your interest!',
      'Single Message Test'
    )
    
    assert_equal 'msg-123', response.id
    assert_equal 'sent', response.status
  end
end
