# frozen_string_literal: true

# Copyright (c) 2025 CloudContactAI LLC
# Licensed under the MIT License. See LICENSE in the project root for license information.

# Example Rails controller for handling CloudContactAI webhooks
# Place this in app/controllers/webhooks/ccai_controller.rb

class Webhooks::CcaiController < ApplicationController
  # Skip CSRF protection for webhook endpoints
  skip_before_action :verify_authenticity_token
  
  # Initialize CCAI client for signature verification
  before_action :initialize_ccai_client
  
  def create
    # Get the raw body for signature verification
    payload_body = request.raw_post
    
    # Parse the JSON payload
    begin
      payload = JSON.parse(payload_body)
    rescue JSON::ParserError => e
      Rails.logger.error "Invalid JSON payload: #{e.message}"
      render json: { error: 'Invalid JSON' }, status: :bad_request
      return
    end
    
    # Verify the signature (optional but recommended)
    signature = request.headers['X-CCAI-Signature']
    webhook_secret = Rails.application.credentials.ccai_webhook_secret
    
    if signature && webhook_secret
      unless @ccai_client.webhook.verify_signature(signature, payload_body, webhook_secret)
        Rails.logger.warn "Invalid webhook signature from #{request.remote_ip}"
        render json: { error: 'Invalid signature' }, status: :unauthorized
        return
      end
    end
    
    # Process the webhook based on its type
    case payload['type']
    when CCAI::Webhook::EventType::MESSAGE_SENT
      handle_message_sent(payload)
      
    when CCAI::Webhook::EventType::MESSAGE_RECEIVED
      handle_message_received(payload)
      
    else
      Rails.logger.warn "Unknown webhook type: #{payload['type']}"
    end
    
    # Always respond with 200 to acknowledge receipt
    render json: { received: true }, status: :ok
  end
  
  private
  
  def initialize_ccai_client
    @ccai_client = CCAI.new(
      client_id: Rails.application.credentials.ccai_client_id,
      api_key: Rails.application.credentials.ccai_api_key
    )
  end
  
  # Handle outbound message events
  def handle_message_sent(payload)
    Rails.logger.info "=== Message Sent Event ==="
    Rails.logger.info "Campaign: #{payload['campaign']['title']} (ID: #{payload['campaign']['id']})"
    Rails.logger.info "From: #{payload['from']}"
    Rails.logger.info "To: #{payload['to']}"
    Rails.logger.info "Message: #{payload['message']}"
    Rails.logger.info "Sent at: #{payload['campaign']['runAt']}"
    
    # Add your custom logic here
    # For example:
    
    # Update message status in database
    # Message.find_by(campaign_id: payload['campaign']['id'])&.update(status: 'sent')
    
    # Track analytics
    # Analytics.track('message_sent', {
    #   campaign_id: payload['campaign']['id'],
    #   recipient: payload['to'],
    #   timestamp: payload['campaign']['runAt']
    # })
    
    # Send notification to team
    # NotificationMailer.message_sent(payload).deliver_later
  end
  
  # Handle inbound message events
  def handle_message_received(payload)
    Rails.logger.info "=== Message Received Event ==="
    Rails.logger.info "Campaign: #{payload['campaign']['title']} (ID: #{payload['campaign']['id']})"
    Rails.logger.info "From: #{payload['from']}"
    Rails.logger.info "To: #{payload['to']}"
    Rails.logger.info "Message: #{payload['message']}"
    
    # Add your custom logic here
    # For example:
    
    # Store the reply in database
    # InboundMessage.create!(
    #   campaign_id: payload['campaign']['id'],
    #   from_number: payload['from'],
    #   to_number: payload['to'],
    #   message: payload['message'],
    #   received_at: Time.current
    # )\n    
    # Process special commands
    message = payload['message'].downcase\n    if message.include?('stop') || message.include?('unsubscribe')
      Rails.logger.info "Processing unsubscribe request from #{payload['from']}"
      # Contact.find_by(phone: payload['from'])&.update(subscribed: false)
      # UnsubscribeJob.perform_later(payload['from'])
      
    elsif message.include?('help')
      Rails.logger.info "Sending help information to #{payload['from']}"
      # HelpResponseJob.perform_later(payload['from'])
      
    else
      # Forward to customer service or trigger auto-response
      # CustomerServiceJob.perform_later(payload)
    end
  end
end

# Add this to your routes.rb:
# Rails.application.routes.draw do
#   namespace :webhooks do
#     post 'ccai', to: 'ccai#create'
#   end
# end

# Add these to your credentials (rails credentials:edit):
# ccai:
#   client_id: your-client-id
#   api_key: your-api-key
#   webhook_secret: your-webhook-secret