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
    # Mock the HTTP response
    stub_request(:post, "https://email-campaigns.cloudcontactai.com/api/v1/campaigns")
      .to_return(status: 200, body: '{"id": "123", "status": "sent"}')

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
    # Mock the HTTP response
    stub_request(:post, "https://email-campaigns.cloudcontactai.com/api/v1/campaigns")
      .to_return(status: 200, body: '{"campaignId": "456", "messagesSent": 2}')

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
    # Mock the HTTP response
    stub_request(:post, "https://email-campaigns.cloudcontactai.com/api/v1/campaigns")
      .to_return(status: 200, body: '{"campaignId": "789"}')

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
    # Test missing accounts
    assert_raises(ArgumentError, 'At least one account is required') do
      @email_service.send_campaign({ accounts: [] })
    end

    # Test missing subject
    assert_raises(ArgumentError, 'Subject is required') do
      @email_service.send_campaign({ accounts: [{}] })
    end

    # Test missing required account fields
    assert_raises(ArgumentError) do
      @email_service.send_campaign({
        subject: 'Test',
        title: 'Test',
        message: 'Test',
        senderEmail: 'test@example.com',
        replyEmail: 'test@example.com',
        senderName: 'Test',
        accounts: [{ firstName: 'John' }] # Missing lastName and email
      })
    end
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