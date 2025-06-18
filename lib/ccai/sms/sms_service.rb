# frozen_string_literal: true

# Copyright (c) 2025 CloudContactAI LLC
# Licensed under the MIT License. See LICENSE in the project root for license information.

require 'ccai/sms/models'

module CCAI
  module SMS
    # SMS service for sending messages through the CCAI API
    class SMSService
      # Create a new SMS service instance
      #
      # @param client [CCAI::Client] The parent CCAI client
      def initialize(client)
        @client = client
      end

      # Send an SMS message to one or more recipients
      #
      # @param accounts [Array<CCAI::SMS::Account>] List of recipient accounts
      # @param message [String] Message content (can include ${firstName} and ${lastName} variables)
      # @param title [String] Campaign title
      # @param options [CCAI::SMS::Options, nil] Optional settings for the SMS send operation
      # @return [CCAI::SMS::Response] API response
      # @raise [ArgumentError] If required parameters are missing or invalid
      def send(accounts, message, title, options = nil)
        # Validate inputs
        raise ArgumentError, 'At least one account is required' if accounts.nil? || accounts.empty?
        raise ArgumentError, 'Message is required' if message.nil? || message.empty?
        raise ArgumentError, 'Title is required' if title.nil? || title.empty?

        # Create options if not provided
        options ||= Options.new

        # Notify progress if callback provided
        options.notify_progress('Preparing to send SMS')

        # Prepare the endpoint and data
        endpoint = "/clients/#{@client.client_id}/campaigns/direct"

        # Convert Account objects to hashes for API compatibility
        accounts_data = accounts.map(&:to_hash)

        campaign_data = {
          accounts: accounts_data,
          message: message,
          title: title
        }

        begin
          # Notify progress if callback provided
          options.notify_progress('Sending SMS')

          # Make the API request
          response_data = @client.request(:post, endpoint, campaign_data)

          # Notify progress if callback provided
          options.notify_progress('SMS sent successfully')

          # Convert response to Response object
          Response.new(response_data)
        rescue => e
          # Notify progress if callback provided
          options.notify_progress('SMS sending failed')

          raise e
        end
      end

      # Send a single SMS message to one recipient
      #
      # @param first_name [String] Recipient's first name
      # @param last_name [String] Recipient's last name
      # @param phone [String] Recipient's phone number (E.164 format)
      # @param message [String] Message content (can include ${firstName} and ${lastName} variables)
      # @param title [String] Campaign title
      # @param options [CCAI::SMS::Options, nil] Optional settings for the SMS send operation
      # @return [CCAI::SMS::Response] API response
      def send_single(first_name, last_name, phone, message, title, options = nil)
        account = Account.new(
          first_name: first_name,
          last_name: last_name,
          phone: phone
        )

        send([account], message, title, options)
      end
    end
  end
end
