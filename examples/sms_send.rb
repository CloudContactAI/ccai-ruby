#!/usr/bin/env ruby
# frozen_string_literal: true

# Copyright (c) 2025 CloudContactAI LLC
# Licensed under the MIT License. See LICENSE in the project root for license information.

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'ccai'

# Initialize the client
client = CCAI.new(
  client_id: '2682',
  api_key: 'eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJpbmZvQGFsbGNvZGUuY29tIiwiaXNzIjoiY2xvdWRjb250YWN0IiwibmJmIjoxNzE5NDQwMjM2LCJpYXQiOjE3MTk0NDAyMzYsInJvbGUiOiJVU0VSIiwiY2xpZW50SWQiOjI2ODIsImlkIjoyNzY0LCJ0eXBlIjoiQVBJX0tFWSIsImtleV9yYW5kb21faWQiOiI1MGRiOTUzZC1hMjUxLTRmZjMtODI5Yi01NjIyOGRhOGE1YTAifQ.PKVjXYHdjBMum9cTgLzFeY2KIb9b2tjawJ0WXalsb8Bckw1RuxeiYKS1bw5Cc36_Rfmivze0T7r-Zy0PVj2omDLq65io0zkBzIEJRNGDn3gx_AqmBrJ3yGnz9s0WTMr2-F1TFPUByzbj1eSOASIKeI7DGufTA5LDrRclVkz32Oo'
)

# Send a single SMS
begin
  response = client.sms.send_single(
    'John',
    'Doe',
    '+14156961732',
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
    phone: '+14156961732'
  ),
  CCAI::SMS::Account.new(
    first_name: 'Jane',
    last_name: 'Smith',
    phone: '+14152440933'
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