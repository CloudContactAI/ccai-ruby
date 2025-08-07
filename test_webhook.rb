#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('lib', __dir__))
require 'ccai'
require 'openssl'
require 'json'

# Initialize the client
client = CCAI.new(
  client_id: ENV['CCAI_CLIENT_ID'],
  api_key: ENV['CCAI_API_KEY']
)

# Test webhook payload processing
puts "Testing webhook payload processing..."
test_payload = {
  'type' => CCAI::Webhook::EventType::MESSAGE_SENT,
  'campaign' => {
    'id' => 123,
    'title' => 'Test Campaign',
    'message' => '',
    'senderPhone' => '+14156961732',
    'createdAt' => '2025-01-14 22:18:28.273',
    'runAt' => ''
  },
  'from' => '+14156961732',
  'to' => '+15551234567',
  'message' => 'Hello John Doe, this is a test message!'
}

webhook_payload = client.webhook.process_payload(test_payload)
puts "✅ Payload processed: #{webhook_payload.type}"
puts "✅ Message sent?: #{webhook_payload.message_sent?}"
puts "✅ From: #{webhook_payload.from}, To: #{webhook_payload.to}"

# Test signature verification with proper HMAC
puts "\nTesting HMAC signature verification..."
body = JSON.generate(test_payload)
secret = 'test-secret-123'
expected_signature = OpenSSL::HMAC.hexdigest('SHA256', secret, body)
signature_with_prefix = "sha256=#{expected_signature}"

result = client.webhook.verify_signature(signature_with_prefix, body, secret)
puts "✅ Signature verification: #{result}"

# Test with invalid signature
invalid_result = client.webhook.verify_signature('sha256=invalid', body, secret)
puts "✅ Invalid signature rejected: #{!invalid_result}"

# Send SMS to +14156961732 for webhook testing
puts "\nSending test SMS to +14156961732..."
begin
  account = CCAI::SMS::Account.new(
    first_name: 'Test',
    last_name: 'User', 
    phone: '+14156961732'
  )
  
  response = client.sms.send(
    [account],
    'Test message for webhook - reply to test inbound webhooks',
    'Webhook Test Campaign'
  )
  
  puts "✅ SMS sent to +14156961732: #{response.campaign_id}"
  puts "Reply to this number to test inbound webhook events"
rescue => e
  puts "❌ SMS failed: #{e.message}"
end