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
    client_id = Rails.application.credentials.ccai_client_id
    event_hash = payload['eventHash']
    webhook_secret = Rails.application.credentials.ccai_webhook_secret

    if signature && webhook_secret
      unless @ccai_client.webhook.verify_signature(signature, client_id, event_hash, webhook_secret)
        Rails.logger.warn "Invalid webhook signature from #{request.remote_ip}"
        render json: { error: 'Invalid signature' }, status: :unauthorized
        return
      end
    end

    # Process the webhook based on its event type
    case payload['eventType']
    when 'message.sent'
      handle_message_sent(payload['data'])

    when 'message.incoming'
      handle_message_received(payload['data'])

    else
      Rails.logger.warn "Unhandled event type: #{payload['eventType']}"
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
  
  # Handle outbound message events (data is the webhook event's "data" object)
  def handle_message_sent(data)
    Rails.logger.info "=== Message Sent Event ==="
    Rails.logger.info "Campaign: #{data['CampaignTitle']} (ID: #{data['CampaignId']})"
    Rails.logger.info "To: #{data['To']}"
    Rails.logger.info "Message: #{data['Message']}"

    # Add your custom logic here
    # For example:

    # Update message status in database
    # Message.find_by(campaign_id: data['CampaignId'])&.update(status: 'sent')

    # Track analytics
    # Analytics.track('message_sent', {
    #   campaign_id: data['CampaignId'],
    #   recipient: data['To']
    # })

    # Send notification to team
    # NotificationMailer.message_sent(data).deliver_later
  end

  # Handle inbound message events (data is the webhook event's "data" object)
  def handle_message_received(data)
    Rails.logger.info "=== Message Received Event ==="
    Rails.logger.info "Campaign: #{data['CampaignTitle']} (ID: #{data['CampaignId']})"
    Rails.logger.info "From: #{data['From']}"
    Rails.logger.info "Message: #{data['Message']}"

    # Add your custom logic here
    # For example:

    # Store the reply in database
    # InboundMessage.create!(
    #   campaign_id: data['CampaignId'],
    #   from_number: data['From'],
    #   message: data['Message'],
    #   received_at: Time.current
    # )

    # Process special commands
    message = data['Message'].to_s.downcase
    if message.include?('stop') || message.include?('unsubscribe')
      Rails.logger.info "Processing unsubscribe request from #{data['From']}"
      # Contact.find_by(phone: data['From'])&.update(subscribed: false)
      # UnsubscribeJob.perform_later(data['From'])

    elsif message.include?('help')
      Rails.logger.info "Sending help information to #{data['From']}"
      # HelpResponseJob.perform_later(data['From'])

    else
      # Forward to customer service or trigger auto-response
      # CustomerServiceJob.perform_later(data)
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