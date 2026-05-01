# frozen_string_literal: true

# Copyright (c) 2025 CloudContactAI LLC
# Licensed under the MIT License. See LICENSE in the project root for license information.

require 'ccai/version'
require 'ccai/client'
require 'ccai/sms/models'
require 'ccai/sms/sms_service'
require 'ccai/sms/mms_service'
require 'ccai/email/email_service'
require 'ccai/webhook/webhook_service'
require 'ccai/contact/contact_service'

# Main module for the CCAI Ruby client
module CCAI
  # Create a new CCAI client
  #
  # @param client_id [String] Client ID for authentication
  # @param api_key [String] API key for authentication
  # @param use_test_environment [Boolean] Whether to use test environment URLs (default: false)
  # @param base_url [String] Override base URL for the core API (optional)
  # @param email_base_url [String] Override base URL for the Email API (optional)
  # @param files_base_url [String] Override base URL for the Files API (optional)
  # @return [CCAI::Client] A new CCAI client
  def self.new(client_id:, api_key:, use_test_environment: false, base_url: nil, email_base_url: nil, files_base_url: nil)
    config = Config.new(
      client_id: client_id,
      api_key: api_key,
      use_test_environment: use_test_environment,
      base_url: base_url,
      email_base_url: email_base_url,
      files_base_url: files_base_url
    )
    Client.new(config)
  end
end
