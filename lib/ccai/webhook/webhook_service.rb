# frozen_string_literal: true

# Copyright (c) 2025 CloudContactAI LLC
# Licensed under the MIT License. See LICENSE in the project root for license information.

require 'digest'
require 'openssl'
require 'json'
begin
  require 'base64'
rescue LoadError
  # Base64 is bundled in Ruby, but may not be required in newer versions
end

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

      # Register a new webhook endpoint
      #
      # If secret is not provided, the server will auto-generate one
      #
      # @param config [Hash] Webhook configuration (url, events, secret, etc.)
      # @return [Hash] Registered webhook details
      def register(config)
        payload = [{
          url: config[:url] || '',
          method: config[:method] || 'POST',
          integrationType: config[:integrationType] || 'ALL'
        }]

        # Only include secretKey if explicitly provided
        secret = config[:secretKey] || config[:secret]
        payload[0][:secretKey] = secret if secret

        result = @client.request(:post, "/v1/client/#{@client.client_id}/integration", payload)
        result.is_a?(Array) && result[0] ? result[0] : result
      end

      # Update an existing webhook configuration
      #
      # If secret is not provided, the server will keep the existing secret
      #
      # @param id [String,Integer] Webhook ID
      # @param config [Hash] Updated webhook configuration
      # @return [Hash] Updated webhook details
      def update(id, config)
        payload = [{
          id: id.to_i,
          url: config[:url] || '',
          method: config[:method] || 'POST',
          integrationType: config[:integrationType] || 'ALL'
        }]

        # Only include secretKey if explicitly provided
        secret = config[:secretKey] || config[:secret]
        payload[0][:secretKey] = secret if secret

        result = @client.request(:post, "/v1/client/#{@client.client_id}/integration", payload)
        result.is_a?(Array) && result[0] ? result[0] : result
      end

      # List all registered webhooks
      #
      # @return [Array<Hash>] Array of webhook configurations
      def list
        @client.request(:get, "/v1/client/#{@client.client_id}/integration")
      end

      # Delete a webhook
      #
      # @param id [String,Integer] Webhook ID
      # @return [Hash] Success response
      def delete(id)
        @client.request(:delete, "/v1/client/#{@client.client_id}/integration/#{id}")
      end

      # Process a webhook payload
      #
      # @param payload [Hash] The webhook payload
      # @return [WebhookPayload] Parsed webhook payload
      def process_payload(payload)
        WebhookPayload.new(payload)
      end

      # Parse a raw webhook JSON payload
      #
      # @param json_payload [String] Raw JSON payload
      # @return [Hash] Parsed webhook event
      # @raise [CCAI::Error] If the payload is invalid JSON
      def parse_event(json_payload)
        data = JSON.parse(json_payload)
        data
      rescue JSON::ParserError => e
        raise CCAI::Error.new("Invalid JSON payload: #{e.message}")
      end

      # Verify a webhook signature using HMAC-SHA256
      #
      # Signature is computed as: HMAC-SHA256(secretKey, clientId:eventHash) encoded in Base64
      #
      # @param signature [String] Signature from the X-CCAI-Signature header (Base64 encoded)
      # @param client_id [String] Client ID
      # @param event_hash [String] Event hash from the webhook payload
      # @param secret [String] Webhook secret
      # @return [Boolean] True if signature is valid
      def verify_signature(signature, client_id, event_hash, secret)
        return false unless signature && client_id && event_hash && secret

        # Compute: HMAC-SHA256(secretKey, "$clientId:$eventHash")
        data = "#{client_id}:#{event_hash}"
        computed = OpenSSL::HMAC.digest('SHA256', secret, data)

        # Encode result in Base64
        computed_base64 = Base64.strict_encode64(computed)

        # Secure comparison to prevent timing attacks
        secure_compare(signature, computed_base64)
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
