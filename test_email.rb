#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('lib', __dir__))
require 'ccai'

# Initialize the client
client = CCAI.new(
  client_id: '2682',
  api_key: 'eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJpbmZvQGFsbGNvZGUuY29tIiwiaXNzIjoiY2xvdWRjb250YWN0IiwibmJmIjoxNzE5NDQwMjM2LCJpYXQiOjE3MTk0NDAyMzYsInJvbGUiOiJVU0VSIiwiY2xpZW50SWQiOjI2ODIsImlkIjoyNzY0LCJ0eXBlIjoiQVBJX0tFWSIsImtleV9yYW5kb21faWQiOiI1MGRiOTUzZC1hMjUxLTRmZjMtODI5Yi01NjIyOGRhOGE1YTAifQ.PKVjXYHdjBMum9cTgLzFeY2KIb9b2tjawJ0WXalsb8Bckw1RuxeiYKS1bw5Cc36_Rfmivze0T7r-Zy0PVj2omDLq65io0zkBzIEJRNGDn3gx_AqmBrJ3yGnz9s0WTMr2-F1TFPUByzbj1eSOASIKeI7DGufTA5LDrRclVkz32Oo'
)

# Test single email
puts "Testing single email..."
begin
  response = client.email.send_single(
    'Andreas',
    'Test',
    'andreas@allcode.com',
    'Ruby Client Test',
    '<h1>Hello Andreas!</h1><p>This is a test from the Ruby client.</p>',
    'noreply@allcode.com',
    'support@allcode.com',
    'AllCode Team',
    'Ruby Email Test'
  )
  puts "✅ Email sent: #{response}"
rescue => e
  puts "❌ Email failed: #{e.message}"
end

# Test email campaign
puts "\nTesting email campaign..."
begin
  campaign = {
    subject: 'Ruby Campaign Test',
    title: 'Ruby Test Campaign',
    message: '<h1>Hello ${firstName}!</h1><p>This is a campaign test.</p>',
    senderEmail: 'noreply@allcode.com',
    replyEmail: 'support@allcode.com',
    senderName: 'AllCode Team',
    accounts: [
      { firstName: 'Andreas', lastName: 'Test', email: 'andreas@allcode.com', phone: '' }
    ],
    campaignType: 'EMAIL',
    addToList: 'noList',
    contactInput: 'accounts',
    fromType: 'single',
    senders: []
  }
  
  response = client.email.send_campaign(campaign)
  puts "✅ Campaign sent: #{response}"
rescue => e
  puts "❌ Campaign failed: #{e.message}"
end