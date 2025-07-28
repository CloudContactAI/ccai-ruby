# frozen_string_literal: true

# Copyright (c) 2025 CloudContactAI LLC
# Licensed under the MIT License. See LICENSE in the project root for license information.

require 'faraday'
require 'json'

module CCAI
  module Email
    # Service for sending email campaigns through the CCAI API
    class EmailService
      BASE_URL = 'https://email-campaigns.cloudcontactai.com/api/v1'

      # Create a new EmailService instance
      #
      # @param client [CCAI::Client] The parent CCAI client
      def initialize(client)
        @client = client
      end

      # Send an email campaign to one or more recipients
      #
      # @param campaign [Hash] The email campaign configuration
      # @param options [CCAI::SMS::Options, nil] Optional settings
      # @return [Hash] API response
      # @raise [ArgumentError] If required fields are missing
      # @raise [CCAI::Error] If the API returns an error
      def send_campaign(campaign, options = nil)
        validate_campaign(campaign)
        
        options&.on_progress&.call('Preparing to send email campaign')
        
        begin
          options&.on_progress&.call('Sending email campaign')
          
          response = custom_request('post', '/campaigns', campaign)
          
          options&.on_progress&.call('Email campaign sent successfully')
          response
        rescue => e
          options&.on_progress&.call('Email campaign sending failed')
          raise e
        end
      end

      # Send a single email to one recipient
      #
      # @param first_name [String] Recipient's first name
      # @param last_name [String] Recipient's last name
      # @param email [String] Recipient's email address
      # @param subject [String] Email subject
      # @param message [String] The HTML message content
      # @param sender_email [String] Sender's email address
      # @param reply_email [String] Reply-to email address
      # @param sender_name [String] Sender's name
      # @param title [String] Campaign title
      # @param options [CCAI::SMS::Options, nil] Optional settings
      # @return [Hash] API response
      def send_single(first_name, last_name, email, subject, message, sender_email, reply_email, sender_name, title, options = nil)
        account = {
          firstName: first_name,
          lastName: last_name,
          email: email,
          phone: '' # Required by Account type but not used for email
        }
        
        campaign = {
          subject: subject,
          title: title,
          message: message,
          senderEmail: sender_email,
          replyEmail: reply_email,
          senderName: sender_name,
          accounts: [account],
          campaignType: 'EMAIL',
          addToList: 'noList',
          contactInput: 'accounts',
          fromType: 'single',
          senders: []
        }
        
        send_campaign(campaign, options)
      end

      private

      # Make a custom API request to the email campaigns API
      #
      # @param method [String] HTTP method
      # @param endpoint [String] API endpoint
      # @param data [Hash, nil] Request data
      # @return [Hash] API response
      def custom_request(method, endpoint, data = nil)
        url = "#{BASE_URL}#{endpoint}"
        
        connection = Faraday.new do |conn|
          conn.headers['Authorization'] = "Bearer #{@client.api_key}"
          conn.headers['Content-Type'] = 'application/json'
          conn.headers['Accept'] = '*/*'
        end

        begin
          response = connection.run_request(method.to_sym, url, data ? data.to_json : nil, nil)

          if response.success?
            response.body.empty? ? {} : JSON.parse(response.body)
          else
            raise CCAI::Error.new("API Error: #{response.status} - #{response.body}")
          end
        rescue Faraday::Error => e
          raise CCAI::Error.new("Request failed: #{e.message}")
        end
      end

      # Validate email campaign configuration
      #
      # @param campaign [Hash] Campaign configuration
      # @raise [ArgumentError] If validation fails
      def validate_campaign(campaign)
        raise ArgumentError, 'At least one account is required' unless campaign[:accounts]&.is_a?(Array) && !campaign[:accounts].empty?
        raise ArgumentError, 'Subject is required' unless campaign[:subject]
        raise ArgumentError, 'Campaign title is required' unless campaign[:title]
        raise ArgumentError, 'Message content is required' unless campaign[:message]
        raise ArgumentError, 'Sender email is required' unless campaign[:senderEmail]
        raise ArgumentError, 'Reply email is required' unless campaign[:replyEmail]
        raise ArgumentError, 'Sender name is required' unless campaign[:senderName]
        
        campaign[:accounts].each_with_index do |account, index|
          raise ArgumentError, "First name is required for account at index #{index}" unless account[:firstName]
          raise ArgumentError, "Last name is required for account at index #{index}" unless account[:lastName]
          raise ArgumentError, "Email is required for account at index #{index}" unless account[:email]
        end
      end
    end
  end
end