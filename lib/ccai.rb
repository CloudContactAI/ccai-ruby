# frozen_string_literal: true

# Copyright (c) 2025 CloudContactAI LLC
# Licensed under the MIT License. See LICENSE in the project root for license information.

require 'ccai/version'
require 'ccai/client'
require 'ccai/sms/models'
require 'ccai/sms/sms_service'
require 'ccai/sms/mms_service'
require 'ccai/email/email_service'
require 'ccai/webhook_service'

# Main module for the CCAI Ruby client
module CCAI
  # Create a new CCAI client
  #
  # @param client_id [String] Client ID for authentication
  # @param api_key [String] API key for authentication
  # @param base_url [String] Base URL for the API (optional)
  # @return [CCAI::Client] A new CCAI client
  def self.new(client_id:, api_key:, base_url: nil)
    config = Config.new(
      client_id: client_id,
      api_key: api_key,
      base_url: base_url || 'https://core-test-cloudcontactai.allcode.com/api'
    )
    Client.new(config)
  end
end
