# frozen_string_literal: true

# Copyright (c) 2025 CloudContactAI LLC
# Licensed under the MIT License. See LICENSE in the project root for license information.

module CCAI
  module SMS
    # Account model representing a recipient
    class Account
      attr_accessor :first_name, :last_name, :phone,
                    :data, :custom_data

      # Create a new Account instance
      #
      # @param first_name [String] Recipient's first name
      # @param last_name [String] Recipient's last name
      # @param phone [String] Recipient's phone number in E.164 format
      # @param data [Hash, nil] Additional key-value pairs for variable substitution.
      #   Use ${key} in your message. Sent to the API as "data".
      # @param custom_data [String, nil] Arbitrary string forwarded as-is to your webhook handler.
      #   Not used in the message body. Sent to the API as "messageData".
      def initialize(first_name:, last_name:, phone:, data: nil, custom_data: nil)
        @first_name = first_name
        @last_name = last_name
        @phone = phone
        @data = data
        @custom_data = custom_data
      end

      # Convert the account to a hash for API requests
      #
      # @return [Hash] Account data
      def to_hash
        hash = {
          firstName: @first_name,
          lastName: @last_name,
          phone: @phone
        }
        hash[:data] = @data if @data
        hash[:messageData] = @custom_data if @custom_data
        hash
      end
    end

    # Response from the SMS API
    class Response
      attr_accessor :id, :status, :campaign_id, :messages_sent, :timestamp,
                    :message, :response_id, :data

      # Create a new Response instance
      #
      # @param data [Hash] Response data from the API. Client#request parses JSON
      #   with symbolize_names: true, so keys may be Symbols or Strings depending
      #   on the caller — accept both.
      def initialize(data)
        @data = data
        @id = data[:id] || data['id']
        @status = data[:status] || data['status']
        @campaign_id = data[:campaignId] || data['campaignId']
        @messages_sent = data[:messagesSent] || data['messagesSent']
        @timestamp = data[:timestamp] || data['timestamp']
        @message = data[:message] || data['message']
        @response_id = data[:responseId] || data['responseId']
      end

      # Get a value from the response data
      #
      # @param key [String] Key to get
      # @return [Object, nil] Value or nil if not found
      def [](key)
        @data[key]
      end
    end

    # Response from the signed URL API
    class SignedUrlResponse
      attr_accessor :signed_s3_url, :file_key, :data

      # Create a new SignedUrlResponse instance
      #
      # @param data [Hash] Response data from the API (Symbol or String keys)
      def initialize(data)
        @data = data
        @signed_s3_url = data[:signedS3Url] || data['signedS3Url']
        @file_key = data[:fileKey] || data['fileKey']
      end

      # Get a value from the response data
      #
      # @param key [String] Key to get
      # @return [Object, nil] Value or nil if not found
      def [](key)
        @data[key]
      end
    end

    # Options for SMS operations
    class Options
      attr_accessor :timeout, :retries, :on_progress

      # Create a new Options instance
      #
      # @param timeout [Integer, nil] Request timeout in seconds
      # @param retries [Integer, nil] Number of retry attempts
      # @param on_progress [Proc, nil] Callback for tracking progress
      def initialize(timeout: nil, retries: nil, on_progress: nil)
        @timeout = timeout
        @retries = retries
        @on_progress = on_progress
      end

      # Notify progress if callback is provided
      #
      # @param status [String] Progress status
      # @return [void]
      def notify_progress(status)
        @on_progress&.call(status)
      end
    end
  end
end
