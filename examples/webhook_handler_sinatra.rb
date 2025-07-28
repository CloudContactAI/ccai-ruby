#!/usr/bin/env ruby
# frozen_string_literal: true

# Copyright (c) 2025 CloudContactAI LLC
# Licensed under the MIT License. See LICENSE in the project root for license information.

# Example Sinatra webhook handler for CloudContactAI webhooks
# Run with: ruby webhook_handler_sinatra.rb

require 'sinatra'
require 'json'
require_relative '../lib/ccai'

# Initialize CCAI client for signature verification
client = CCAI.new(
  client_id: ENV['CCAI_CLIENT_ID'] || 'your-client-id',
  api_key: ENV['CCAI_API_KEY'] || 'your-api-key'
)

# Webhook secret for signature verification
WEBHOOK_SECRET = ENV['CCAI_WEBHOOK_SECRET'] || 'your-webhook-secret'

# Webhook endpoint
post '/webhooks/ccai' do
  # Get the raw body for signature verification
  request.body.rewind
  payload_body = request.body.read
  
  # Parse the JSON payload
  begin
    payload = JSON.parse(payload_body)
  rescue JSON::ParserError => e
    puts "Invalid JSON payload: #{e.message}"
    halt 400, 'Invalid JSON'
  end
  
  # Verify the signature (optional but recommended)
  signature = request.env['HTTP_X_CCAI_SIGNATURE']
  
  if signature && WEBHOOK_SECRET
    unless client.webhook.verify_signature(signature, payload_body, WEBHOOK_SECRET)
      puts "Invalid webhook signature"
      halt 401, 'Invalid signature'
    end
  end
  
  # Process the webhook based on its type
  case payload['type']
  when CCAI::Webhook::EventType::MESSAGE_SENT
    handle_message_sent(payload)
    
  when CCAI::Webhook::EventType::MESSAGE_RECEIVED
    handle_message_received(payload)
    
  else
    puts "Unknown webhook type: #{payload['type']}"
  end
  
  # Always respond with 200 to acknowledge receipt
  status 200
  content_type :json
  { received: true }.to_json
end

# Handle outbound message events
def handle_message_sent(payload)
  puts "=== Message Sent Event ==="
  puts "Campaign: #{payload['campaign']['title']} (ID: #{payload['campaign']['id']})"
  puts "From: #{payload['from']}"
  puts "To: #{payload['to']}"
  puts "Message: #{payload['message']}"
  puts "Sent at: #{payload['campaign']['runAt']}"
  
  # Add your custom logic here
  # For example:
  # - Update your database with delivery status
  # - Trigger analytics events
  # - Send notifications to your team
end

# Handle inbound message events
def handle_message_received(payload)
  puts "=== Message Received Event ==="
  puts "Campaign: #{payload['campaign']['title']} (ID: #{payload['campaign']['id']})"
  puts "From: #{payload['from']}"
  puts "To: #{payload['to']}"
  puts "Message: #{payload['message']}"
  
  # Add your custom logic here
  # For example:
  # - Store the reply in your database
  # - Trigger automated responses
  # - Forward to customer service
  # - Update contact preferences
  
  # Example: Simple auto-reply for certain keywords
  message = payload['message'].downcase
  if message.include?('stop') || message.include?('unsubscribe')
    puts "Processing unsubscribe request from #{payload['from']}"
    # Add unsubscribe logic here
  elsif message.include?('help')
    puts "Sending help information to #{payload['from']}"
    # Add help response logic here
  end
end

# Health check endpoint
get '/health' do
  content_type :json
  { status: 'ok', timestamp: Time.now.iso8601 }.to_json
end

# Start the server
if __FILE__ == $0
  puts "Starting CloudContactAI webhook handler on port 4567"
  puts "Webhook endpoint: http://localhost:4567/webhooks/ccai"
  puts "Health check: http://localhost:4567/health"
  puts ""
  puts "Environment variables:"
  puts "  CCAI_CLIENT_ID: #{ENV['CCAI_CLIENT_ID'] ? 'Set' : 'Not set'}"
  puts "  CCAI_API_KEY: #{ENV['CCAI_API_KEY'] ? 'Set' : 'Not set'}"
  puts "  CCAI_WEBHOOK_SECRET: #{ENV['CCAI_WEBHOOK_SECRET'] ? 'Set' : 'Not set'}"
  puts ""
  
  set :port, ENV['PORT'] || 4567
  set :bind, '0.0.0.0'
end