# frozen_string_literal: true

# Copyright (c) 2025 CloudContactAI LLC
# Licensed under the MIT License. See LICENSE in the project root for license information.

require 'faraday'
require 'json'
require 'ccai/sms/sms_service'
require 'ccai/sms/mms_service'
require 'ccai/email/email_service'
require 'ccai/webhook/webhook_service'
require 'ccai/contact/contact_service'

module CCAI
  # Configuration for the CCAI client
  class Config
    attr_reader :client_id, :api_key, :base_url, :email_base_url, :files_base_url, :use_test_environment

    # Production URLs
    PROD_BASE_URL  = 'https://core.cloudcontactai.com/api'
    PROD_EMAIL_URL = 'https://email-campaigns.cloudcontactai.com/api/v1'
    PROD_FILES_URL = 'https://files.cloudcontactai.com'

    # Test environment URLs
    TEST_BASE_URL  = 'https://core-test-cloudcontactai.allcode.com/api'
    TEST_EMAIL_URL = 'https://email-campaigns-test-cloudcontactai.allcode.com/api/v1'
    TEST_FILES_URL = 'https://files-test-cloudcontactai.allcode.com'

    # Create a new configuration
    #
    # @param client_id [String] Client ID for authentication
    # @param api_key [String] API key for authentication
    # @param use_test_environment [Boolean] Whether to use test environment URLs (default: false)
    # @param base_url [String, nil] Override base URL for the core API
    # @param email_base_url [String, nil] Override base URL for the Email API
    # @param files_base_url [String, nil] Override base URL for the Files API
    def initialize(client_id:, api_key:, use_test_environment: false, base_url: nil, email_base_url: nil, files_base_url: nil)
      @client_id = client_id
      @api_key = api_key
      @use_test_environment = use_test_environment

      # Apply URLs: explicit override > env variable > test/prod default
      @base_url = base_url ||
                  ENV.fetch('CCAI_BASE_URL', nil) ||
                  (use_test_environment ? TEST_BASE_URL : PROD_BASE_URL)

      @email_base_url = email_base_url ||
                        ENV.fetch('CCAI_EMAIL_BASE_URL', nil) ||
                        (use_test_environment ? TEST_EMAIL_URL : PROD_EMAIL_URL)

      @files_base_url = files_base_url ||
                        ENV.fetch('CCAI_FILES_BASE_URL', nil) ||
                        (use_test_environment ? TEST_FILES_URL : PROD_FILES_URL)
    end
  end

  # Main client for interacting with the CloudContactAI API
  class Client
    attr_reader :config, :sms, :mms, :email, :webhook, :contact

    # Create a new CCAI client instance
    #
    # @param config [CCAI::Config] Configuration for the client
    # @raise [ArgumentError] If required configuration is missing
    def initialize(config)
      raise ArgumentError, 'Config is required' unless config
      raise ArgumentError, 'Client ID is required' if config.client_id.nil? || config.client_id.empty?
      raise ArgumentError, 'API Key is required' if config.api_key.nil? || config.api_key.empty?

      @config = config
      @connection = Faraday.new do |conn|
        conn.headers['Authorization'] = "Bearer #{config.api_key}"
        conn.headers['Content-Type'] = 'application/json'
        conn.headers['Accept'] = '*/*'
      end

      # Initialize the SMS service
      @sms = SMS::SMSService.new(self)

      # Initialize the MMS service
      @mms = SMS::MMSService.new(self)

      # Initialize the Email service
      @email = Email::EmailService.new(self)

      # Initialize the Webhook service
      @webhook = Webhook::WebhookService.new(self)

      # Initialize the Contact service
      @contact = Contact::ContactService.new(self)
    end

    # Get the client ID
    #
    # @return [String] Client ID
    def client_id
      @config.client_id
    end

    # Get the API key
    #
    # @return [String] API key
    def api_key
      @config.api_key
    end

    # Get the base URL for the core API
    #
    # @return [String] Base URL
    def base_url
      @config.base_url
    end

    # Get the base URL for the Email API
    #
    # @return [String] Email base URL
    def email_base_url
      @config.email_base_url
    end

    # Get the base URL for the Files API
    #
    # @return [String] Files base URL
    def files_base_url
      @config.files_base_url
    end

    # Whether the test environment is active
    #
    # @return [Boolean]
    def test_environment?
      @config.use_test_environment
    end

    # Make an authenticated API request to the core CCAI API
    #
    # @param method [Symbol] HTTP method (:get, :post, etc.)
    # @param endpoint [String] API endpoint
    # @param data [Hash, nil] Request data
    # @param headers [Hash, nil] Additional headers
    # @return [Hash] API response
    # @raise [CCAI::Error] If the API returns an error
    def request(method, endpoint, data = nil, headers = nil)
      url = "#{@config.base_url}#{endpoint}"

      begin
        response = @connection.run_request(method, url, data ? data.to_json : nil, headers)

        if response.success?
          response.body.empty? ? {} : JSON.parse(response.body)
        else
          raise Error.new("API Error: #{response.status} - #{response.body}")
        end
      rescue Faraday::Error => e
        raise Error.new("Request failed: #{e.message}")
      end
    end
  end

  # Base error class for CCAI errors
  class Error < StandardError; end
end
