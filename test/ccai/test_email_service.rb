# frozen_string_literal: true

# Copyright (c) 2025 CloudContactAI LLC
# Licensed under the MIT License. See LICENSE in the project root for license information.

require 'test_helper'

class TestEmailService < Minitest::Test
  def setup
    @config = CCAI::Config.new(
      client_id: 'test_client_id',
      api_key: 'test_api_key'
    )
    @client = CCAI::Client.new(@config)
    @email_service = @client.email
  end

  def test_send_single_email
    stub_request(:post, "https://email-campaigns.cloudcontactai.com/api/v1/campaigns")
      .with(
        headers: {
          'Authorization' => 'Bearer test_api_key',
          'Content-Type' => 'application/json',
          'AccountId' => 'test_client_id',
          'ClientId' => 'test_client_id'
        }
      )
      .to_return(status: 200, body: '{"id": "123", "status": "sent"}', headers: { 'Content-Type' => 'application/json' })

    response = @email_service.send_single(
      'John',
      'Doe',
      'john@example.com',
      'Test Subject',
      '<p>Test message</p>',
      'sender@example.com',
      'reply@example.com',
      'Test Sender',
      'Test Campaign'
    )

    assert_equal '123', response['id']
    assert_equal 'sent', response['status']
  end

  def test_send_campaign
    stub_request(:post, "https://email-campaigns.cloudcontactai.com/api/v1/campaigns")
      .to_return(status: 200, body: '{"campaignId": "456", "messagesSent": 2}', headers: { 'Content-Type' => 'application/json' })

    campaign = {
      subject: 'Test Subject',
      title: 'Test Campaign',
      message: '<p>Hello ${firstName}</p>',
      senderEmail: 'sender@example.com',
      replyEmail: 'reply@example.com',
      senderName: 'Test Sender',
      accounts: [
        { firstName: 'John', lastName: 'Doe', email: 'john@example.com', phone: '' },
        { firstName: 'Jane', lastName: 'Smith', email: 'jane@example.com', phone: '' }
      ],
      campaignType: 'EMAIL',
      addToList: 'noList',
      contactInput: 'accounts',
      fromType: 'single',
      senders: []
    }

    response = @email_service.send_campaign(campaign)

    assert_equal '456', response['campaignId']
    assert_equal 2, response['messagesSent']
  end

  def test_send_campaign_with_progress_callback
    stub_request(:post, "https://email-campaigns.cloudcontactai.com/api/v1/campaigns")
      .to_return(status: 200, body: '{"campaignId": "789"}', headers: { 'Content-Type' => 'application/json' })

    progress_messages = []
    options = CCAI::SMS::Options.new(
      on_progress: ->(status) { progress_messages << status }
    )

    campaign = {
      subject: 'Test Subject',
      title: 'Test Campaign',
      message: '<p>Test</p>',
      senderEmail: 'sender@example.com',
      replyEmail: 'reply@example.com',
      senderName: 'Test Sender',
      accounts: [{ firstName: 'John', lastName: 'Doe', email: 'john@example.com', phone: '' }],
      campaignType: 'EMAIL',
      addToList: 'noList',
      contactInput: 'accounts',
      fromType: 'single',
      senders: []
    }

    @email_service.send_campaign(campaign, options)

    assert_includes progress_messages, 'Preparing to send email campaign'
    assert_includes progress_messages, 'Sending email campaign'
    assert_includes progress_messages, 'Email campaign sent successfully'
  end

  def test_validation_errors
    assert_raises(ArgumentError) do
      @email_service.send_campaign({ accounts: [] })
    end

    assert_raises(ArgumentError) do
      @email_service.send_campaign({ accounts: [{}] })
    end

    assert_raises(ArgumentError) do
      @email_service.send_campaign({
        subject: 'Test',
        title: 'Test',
        message: 'Test',
        senderEmail: 'test@example.com',
        replyEmail: 'test@example.com',
        senderName: 'Test',
        accounts: [{ firstName: 'John' }]
      })
    end
  end

  def test_send_campaign_with_custom_account_id_and_data
    stub_request(:post, "https://email-campaigns.cloudcontactai.com/api/v1/campaigns")
      .with(
        body: hash_including(
          accounts: [hash_including(
            firstName: 'John',
            customAccountId: 'ext-id-123',
            data: { tier: 'gold', locale: 'en-US' }
          )]
        )
      )
      .to_return(
        status: 200,
        body: { id: '123', status: 'PENDING', message: 'Email sent', responseId: 'resp-xyz' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    campaign = {
      subject: 'Test', title: 'Test', message: '<p>Test</p>',
      senderEmail: 'sender@example.com', replyEmail: 'reply@example.com',
      senderName: 'Sender',
      accounts: [{
        firstName: 'John', lastName: 'Doe', email: 'john@example.com', phone: '',
        customAccountId: 'ext-id-123',
        data: { tier: 'gold', locale: 'en-US' }
      }],
      campaignType: 'EMAIL', addToList: 'noList', contactInput: 'accounts',
      fromType: 'single', senders: []
    }

    response = @email_service.send_campaign(campaign)

    assert_equal '123', response['id']
    assert_equal 'Email sent', response['message']
    assert_equal 'resp-xyz', response['responseId']
  end

  def test_send_single_with_data_and_custom_account_id
    stub_request(:post, "https://email-campaigns.cloudcontactai.com/api/v1/campaigns")
      .with(
        body: hash_including(
          accounts: [hash_including(
            firstName: 'Bob',
            customAccountId: 'ext-id-456',
            data: { city: 'Miami', plan: 'premium' }
          )]
        )
      )
      .to_return(status: 200, body: '{"id": "789", "status": "sent"}', headers: { 'Content-Type' => 'application/json' })

    response = @email_service.send_single(
      'Bob', 'Smith', 'bob@example.com',
      'Hello', '<p>Hi Bob</p>',
      'sender@example.com', 'reply@example.com', 'Sender', 'Campaign',
      nil,
      data: { city: 'Miami', plan: 'premium' },
      custom_account_id: 'ext-id-456'
    )

    assert_equal '789', response['id']
  end

  def test_email_uses_client_url_not_hardcoded
    config = CCAI::Config.new(
      client_id: 'test_client_id',
      api_key: 'test_api_key',
      use_test_environment: true
    )
    client = CCAI::Client.new(config)

    stub_request(:post, "https://email-campaigns-test-cloudcontactai.allcode.com/api/v1/campaigns")
      .to_return(status: 200, body: '{"id":"1"}', headers: { 'Content-Type' => 'application/json' })

    response = client.email.send_single(
      'John', 'Doe', 'john@example.com',
      'Subject', '<p>Msg</p>',
      'sender@example.com', 'reply@example.com', 'Sender', 'Title'
    )

    assert_equal '1', response['id']
  end
end
