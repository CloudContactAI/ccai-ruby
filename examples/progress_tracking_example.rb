#!/usr/bin/env ruby
# frozen_string_literal: true

# Copyright (c) 2025 CloudContactAI LLC
# Licensed under the MIT License. See LICENSE in the project root for license information.

require 'ccai'
require 'time'

# Initialize the client
client = CCAI.new(
  client_id: 'YOUR-CLIENT-ID',
  api_key: 'YOUR-API-KEY'
)

# Create options with progress tracking
options = CCAI::SMS::Options.new(
  timeout: 60,
  retries: 3,
  on_progress: ->(status) {
    puts "#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} - #{status}"
  }
)

# Define recipients
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

# Send SMS with progress tracking
begin
  response = client.sms.send(
    accounts,
    'Hello ${firstName}, this is a test message with progress tracking!',
    'Progress Tracking Test',
    options
  )
  
  puts "Campaign sent with ID: #{response.campaign_id}"
rescue => e
  puts "Error: #{e.message}"
end
