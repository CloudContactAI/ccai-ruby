#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('lib', __dir__))
require 'ccai'

# Load environment variables
begin
  require 'dotenv'
  Dotenv.load
rescue LoadError
  # dotenv not available, use system env vars
end

# Initialize the client
client = CCAI.new(
  client_id: ENV['CCAI_CLIENT_ID'],
  api_key: ENV['CCAI_API_KEY']
)

# Test single email
puts "Testing single email..."
begin
  response = client.email.send_single(
    ENV['TEST_FIRST_NAME'] || 'Test',
    ENV['TEST_LAST_NAME'] || 'User',
    ENV['TEST_EMAIL'],
    ENV['TEST_SUBJECT'] || 'Ruby Client Test',
    ENV['TEST_MESSAGE'] || '<h1>Hello!</h1><p>This is a test from the Ruby client.</p>',
    ENV['SENDER_EMAIL'],
    ENV['REPLY_EMAIL'],
    ENV['SENDER_NAME'] || 'CCAI Ruby Client',
    ENV['CAMPAIGN_TITLE'] || 'Ruby Email Test'
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
    senderEmail: ENV['SENDER_EMAIL'],
    replyEmail: ENV['REPLY_EMAIL'],
    senderName: ENV['SENDER_NAME'] || 'CCAI Ruby Client',
    accounts: [
      { firstName: ENV['TEST_FIRST_NAME'] || 'Test', lastName: ENV['TEST_LAST_NAME'] || 'User', email: ENV['TEST_EMAIL'], phone: '' }
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