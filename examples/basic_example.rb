#!/usr/bin/env ruby
# frozen_string_literal: true

# Copyright (c) 2025 CloudContactAI LLC
# Licensed under the MIT License. See LICENSE in the project root for license information.

require 'ccai'

# Initialize the client
client = CCAI.new(
  client_id: 'YOUR-CLIENT-ID',
  api_key: 'YOUR-API-KEY'
)

# Send a single SMS
response = client.sms.send_single(
  'John',
  'Doe',
  '+15551234567',
  'Hello ${firstName}, this is a test message!',
  'Test Campaign'
)

puts "Message sent with ID: #{response.id}"

# Send to multiple recipients
accounts = [
  CCAI::SMS::Account.new(
    first_name: 'John',
    last_name: 'Doe',
    phone: '+15551234567'
  ),
  CCAI::SMS::Account.new(
    first_name: 'Jane',
    last_name: 'Smith',
    phone: '+15559876543'
  )
]

campaign_response = client.sms.send(
  accounts,
  'Hello ${firstName} ${lastName}, this is a test message!',
  'Bulk Test Campaign'
)

puts "Campaign sent with ID: #{campaign_response.campaign_id}"
