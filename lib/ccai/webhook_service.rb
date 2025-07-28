# frozen_string_literal: true

# Copyright (c) 2025 CloudContactAI LLC
# Licensed under the MIT License. See LICENSE in the project root for license information.

require 'digest'
require 'openssl'
require 'json'

module CCAI
  module Webhook
    # Event types supported by CloudContactAI webhooks
    module EventType
      MESSAGE_SENT = 'message.sent'
      MESSAGE_RECEIVED = 'message.received'
    end

    # Webhook payload structure
    class WebhookPayload
      attr_reader :type, :campaign, :from, :to, :message
      
      def initialize(payload)
        @type = payload['type']
        @campaign = payload['campaign']
        @from = payload['from']
        @to = payload['to']
        @message = payload['message']
      end
      
      def message_sent?
        @type == EventType::MESSAGE_SENT
      end
      
      def message_received?
        @type == EventType::MESSAGE_RECEIVED
      end
    end

    # Service for handling CloudContactAI webhooks
    class WebhookService
      # Create a new WebhookService instance
      #
      # @param client [CCAI::Client] The parent CCAI client
      def initialize(client)
        @client = client
      end

      # Process a webhook payload
      #
      # @param payload [Hash] The webhook payload
      # @return [WebhookPayload] Parsed webhook payload
      def process_payload(payload)
        WebhookPayload.new(payload)
      end

      # Verify a webhook signature using HMAC-SHA256
      #
      # @param signature [String] Signature from the X-CCAI-Signature header
      # @param body [String] Raw request body
      # @param secret [String] Webhook secret
      # @return [Boolean] True if signature is valid
      def verify_signature(signature, body, secret)
        return false unless signature && body && secret
        
        # Remove 'sha256=' prefix if present
        signature = signature.sub(/^sha256=/, '')
        
        # Calculate expected signature
        expected = OpenSSL::HMAC.hexdigest('SHA256', secret, body)
        
        # Secure comparison to prevent timing attacks
        secure_compare(signature, expected)
      end
      
      private
      
      # Secure string comparison to prevent timing attacks
      def secure_compare(a, b)
        return false unless a.length == b.length
        
        result = 0
        a.bytes.zip(b.bytes) { |x, y| result |= x ^ y }
        result == 0
      end
    end
  end
end