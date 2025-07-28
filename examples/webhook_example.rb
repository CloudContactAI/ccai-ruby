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

# Example 1: Register a webhook
def register_webhook(client)
  puts "=== Registering Webhook ==="
  
  begin
    config = {
      url: 'https://your-app.com/webhooks/ccai',
      events: [CCAI::Webhook::EventType::MESSAGE_SENT, CCAI::Webhook::EventType::MESSAGE_RECEIVED],
      secret: 'your-webhook-secret'
    }
    
    response = client.webhook.register(config)
    puts "Webhook registered successfully: #{response}"
    response
  rescue => e
    puts "Error registering webhook: #{e.message}"
    nil
  end
end

# Example 2: List all webhooks
def list_webhooks(client)
  puts "\n=== Listing Webhooks ==="
  
  begin
    webhooks = client.webhook.list
    puts "Registered webhooks: #{webhooks}"
    webhooks
  rescue => e
    puts "Error listing webhooks: #{e.message}"
    []
  end
end

# Example 3: Update a webhook
def update_webhook(client, webhook_id)
  puts "\n=== Updating Webhook ==="
  
  begin
    config = {
      url: 'https://your-app.com/webhooks/ccai-updated',
      events: [CCAI::Webhook::EventType::MESSAGE_RECEIVED]
    }
    
    response = client.webhook.update(webhook_id, config)
    puts "Webhook updated successfully: #{response}"
    response
  rescue => e
    puts "Error updating webhook: #{e.message}"
    nil
  end
end

# Example 4: Delete a webhook
def delete_webhook(client, webhook_id)
  puts "\n=== Deleting Webhook ==="
  
  begin
    response = client.webhook.delete(webhook_id)
    puts "Webhook deleted successfully: #{response}"
    response
  rescue => e
    puts "Error deleting webhook: #{e.message}"
    nil
  end
end

# Example 5: Verify webhook signature
def verify_webhook_signature(client)
  puts "\n=== Verifying Webhook Signature ==="
  
  # Example webhook payload
  signature = 'sha256=example-signature'
  body = '{"type":"message.sent","campaign":{"id":123,"title":"Test"}}'
  secret = 'your-webhook-secret'
  
  is_valid = client.webhook.verify_signature(signature, body, secret)
  puts "Signature valid: #{is_valid}"
  is_valid
end

# Example webhook handler (for use in a web framework like Sinatra or Rails)
def example_webhook_handler
  puts "\n=== Example Webhook Handler ==="
  puts <<~RUBY
    # Example Sinatra webhook handler
    require 'sinatra'
    require 'json'
    
    post '/webhooks/ccai' do
      # Get the raw body for signature verification
      request.body.rewind
      payload_body = request.body.read
      
      # Parse the JSON payload
      payload = JSON.parse(payload_body)
      
      # Verify the signature (optional but recommended)
      signature = request.env['HTTP_X_CCAI_SIGNATURE']
      secret = ENV['CCAI_WEBHOOK_SECRET']
      
      if signature && secret
        unless client.webhook.verify_signature(signature, payload_body, secret)
          halt 401, 'Invalid signature'
        end
      end
      
      # Process the webhook based on its type
      case payload['type']
      when '#{CCAI::Webhook::EventType::MESSAGE_SENT}'
        puts "Message sent to: \#{payload['to']}"
        puts "Campaign: \#{payload['campaign']['title']}"
        # Add your custom logic here
        
      when '#{CCAI::Webhook::EventType::MESSAGE_RECEIVED}'
        puts "Message received from: \#{payload['from']}"
        puts "Message: \#{payload['message']}"
        # Add your custom logic here
        
      else
        puts "Unknown webhook type: \#{payload['type']}"
      end
      
      # Always respond with 200 to acknowledge receipt
      status 200
      { received: true }.to_json
    end
  RUBY
end

# Run the examples
webhook = register_webhook(client)
list_webhooks(client)

if webhook && webhook['id']
  update_webhook(client, webhook['id'])
  delete_webhook(client, webhook['id'])
end

verify_webhook_signature(client)
example_webhook_handler