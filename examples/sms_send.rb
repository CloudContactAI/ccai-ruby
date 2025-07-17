#!/usr/bin/env ruby
# frozen_string_literal: true

# Copyright (c) 2025 CloudContactAI LLC
# Licensed under the MIT License. See LICENSE in the project root for license information.

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'ccai'

# Initialize the client
client = CCAI.new(
  client_id: ENV['CCAI_CLIENT_ID'] || 'YOUR_CLIENT_ID',
  api_key: ENV['CCAI_API_KEY'] || 'YOUR_API_KEY'
)

# Send a single SMS
begin
  response = client.sms.send_single(
    'John',
    'Doe',
    ENV['CCAI_TEST_PHONE'] || '+1234567890',
    'Hello ${firstName}, this is a test message!',
    'Test Campaign'
  )
  puts "Message sent with ID: #{response.id}"
rescue => e
  puts "Error sending single SMS: #{e.message}"
end

# Send to multiple recipients
accounts = [
  CCAI::SMS::Account.new(
    first_name: 'John',
    last_name: 'Doe',
    phone: ENV['CCAI_TEST_PHONE'] || '+1234567890'
  ),
  CCAI::SMS::Account.new(
    first_name: 'Jane',
    last_name: 'Smith',
    phone: ENV['CCAI_TEST_PHONE2'] || '+1987654321'
  )
]

begin
  campaign_response = client.sms.send(
    accounts,
    'Hello ${firstName} ${lastName}, this is a test message!',
    'Bulk Test Campaign'
  )
  puts "Campaign sent with ID: #{campaign_response.campaign_id}"
rescue => e
  puts "Error sending bulk SMS: #{e.message}"
end