# frozen_string_literal: true

# Copyright (c) 2025 CloudContactAI LLC
# Licensed under the MIT License. See LICENSE in the project root for license information.

module CCAI
  module ContactValidator
    # Service for validating email addresses and phone numbers
    class ContactValidatorService
      # Create a new ContactValidatorService instance
      #
      # @param client [CCAI::Client] The parent CCAI client
      def initialize(client)
        @client = client
      end

      # Validate a single email address
      #
      # @param email [String] Email address to validate
      # @return [Hash] Validation result with contactField, type, status and metadata
      def validate_email(email)
        @client.request(:post, '/v1/contact-validator/email', { email: email })
      end

      # Validate multiple email addresses (up to 50)
      #
      # @param emails [Array<String>] List of email addresses to validate
      # @return [Hash] Bulk validation results with summary
      def validate_emails(emails)
        @client.request(:post, '/v1/contact-validator/emails', { emails: emails })
      end

      # Validate a single phone number
      #
      # @param phone [String] Phone number in E.164 format (e.g. +15551234567)
      # @param country_code [String, nil] Optional ISO 3166-1 alpha-2 country code (e.g. "US")
      # @return [Hash] Validation result with contactField, type, status and metadata
      def validate_phone(phone, country_code: nil)
        payload = { phone: phone }
        payload[:countryCode] = country_code if country_code
        @client.request(:post, '/v1/contact-validator/phone', payload)
      end

      # Validate multiple phone numbers (up to 50)
      #
      # @param phones [Array<Hash>] List of phone inputs with :phone and optional :countryCode
      # @return [Hash] Bulk validation results with summary
      def validate_phones(phones)
        @client.request(:post, '/v1/contact-validator/phones', { phones: phones })
      end
    end
  end
end
