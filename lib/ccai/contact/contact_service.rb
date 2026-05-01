# frozen_string_literal: true

# Copyright (c) 2025 CloudContactAI LLC
# Licensed under the MIT License. See LICENSE in the project root for license information.

module CCAI
  module Contact
    # Service for managing contact preferences (opt-out)
    class ContactService
      # Create a new ContactService instance
      #
      # @param client [CCAI::Client] The parent CCAI client
      def initialize(client)
        @client = client
      end

      # Set the do-not-text preference for a contact
      #
      # @param do_not_text [Boolean] Whether to opt the contact out of text messages
      # @param contact_id [String, nil] Contact ID (optional if phone is provided)
      # @param phone [String, nil] Phone number (optional if contact_id is provided)
      # @return [Hash] API response
      def set_do_not_text(do_not_text, contact_id: nil, phone: nil)
        payload = {
          clientId: @client.client_id,
          doNotText: do_not_text
        }

        payload[:contactId] = contact_id if contact_id
        payload[:phone] = phone if phone

        @client.request(:put, '/account/do-not-text', payload)
      end
    end
  end
end
