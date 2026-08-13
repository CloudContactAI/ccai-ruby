#!/usr/bin/env ruby
# frozen_string_literal: true

# Copyright (c) 2025 CloudContactAI LLC
# Licensed under the MIT License. See LICENSE in the project root for license information.

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'ccai'
require 'json'

# Initialize the client
client = CCAI.new(
  client_id: ENV['CCAI_CLIENT_ID'] || 'YOUR_CLIENT_ID',
  api_key: ENV['CCAI_API_KEY'] || 'YOUR_API_KEY'
)

# Example 1: Register a webhook
def register_webhook(client)
  puts "=== Registering Webhook ==="
  
  begin
    config = {
      url: 'https://your-app.com/webhooks/ccai',
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
      url: 'https://your-app.com/webhooks/ccai-updated'
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
  body = '{"eventType":"message.sent","eventHash":"abc123hash","data":{"To":"+15551234567"}}'
  payload = JSON.parse(body)
  client_id = ENV['CCAI_CLIENT_ID']
  event_hash = payload['eventHash']
  secret = 'your-webhook-secret'

  is_valid = client.webhook.verify_signature(signature, client_id, event_hash, secret)
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
      client_id = ENV['CCAI_CLIENT_ID']
      event_hash = payload['eventHash']
      secret = ENV['CCAI_WEBHOOK_SECRET']

      if signature && secret
        unless client.webhook.verify_signature(signature, client_id, event_hash, secret)
          halt 401, 'Invalid signature'
        end
      end

      # Process the webhook based on its event type
      data = payload['data']
      case payload['eventType']
      when 'message.sent'
        puts "Message delivered to: \#{data['To']}"
        puts "Campaign: \#{data['CampaignTitle']}"
        # Add your custom logic here

      when 'message.incoming'
        puts "Reply from: \#{data['From']}"
        puts "Message: \#{data['Message']}"
        # Add your custom logic here

      else
        puts "Unhandled event type: \#{payload['eventType']}"
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