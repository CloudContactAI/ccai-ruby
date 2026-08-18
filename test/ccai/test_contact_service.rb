# frozen_string_literal: true

# Copyright (c) 2025 CloudContactAI LLC
# Licensed under the MIT License. See LICENSE in the project root for license information.

require 'test_helper'

class TestContactService < Minitest::Test
  def setup
    @config = CCAI::Config.new(
      client_id: 'test_client_id',
      api_key: 'test_api_key'
    )
    @client = CCAI::Client.new(@config)
    @contact_service = @client.contact
  end

  def test_set_do_not_text_opt_out
    stub_request(:put, "https://core.cloudcontactai.com/api/account/do-not-text")
      .with(
        body: {
          clientId: 'test_client_id',
          doNotText: true,
          phone: '+15551234567'
        }.to_json
      )
      .to_return(
        status: 200,
        body: '{"contactId":"12345","phone":"+15551234567","doNotText":true}',
        headers: { 'Content-Type' => 'application/json' }
      )

    response = @contact_service.set_do_not_text(true, phone: '+15551234567')

    assert_equal '12345', response[:contactId]
    assert_equal '+15551234567', response[:phone]
    assert response[:doNotText]
  end

  def test_set_do_not_text_opt_in
    stub_request(:put, "https://core.cloudcontactai.com/api/account/do-not-text")
      .with(
        body: {
          clientId: 'test_client_id',
          doNotText: false,
          phone: '+15551234567'
        }.to_json
      )
      .to_return(
        status: 200,
        body: '{"contactId":"12345","phone":"+15551234567","doNotText":false}',
        headers: { 'Content-Type' => 'application/json' }
      )

    response = @contact_service.set_do_not_text(false, phone: '+15551234567')

    refute response[:doNotText]
  end

  def test_set_do_not_text_with_contact_id
    stub_request(:put, "https://core.cloudcontactai.com/api/account/do-not-text")
      .with(
        body: {
          clientId: 'test_client_id',
          doNotText: true,
          contactId: '98765'
        }.to_json
      )
      .to_return(
        status: 200,
        body: '{"contactId":"98765","phone":"","doNotText":true}',
        headers: { 'Content-Type' => 'application/json' }
      )

    response = @contact_service.set_do_not_text(true, contact_id: '98765')

    assert_equal '98765', response[:contactId]
  end
end
