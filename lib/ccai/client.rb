# frozen_string_literal: true

# Copyright (c) 2025 CloudContactAI LLC
# Licensed under the MIT License. See LICENSE in the project root for license information.

require 'faraday'
require 'json'
require 'ccai/sms/sms_service'
require 'ccai/sms/mms_service'

module CCAI
  # Configuration for the CCAI client
  class Config
    attr_reader :client_id, :api_key, :base_url

    # Create a new configuration
    #
    # @param client_id [String] Client ID for authentication
    # @param api_key [String] API key for authentication
    # @param base_url [String] Base URL for the API
    def initialize(client_id:, api_key:, base_url: 'https://core.cloudcontactai.com/api')
      @client_id = client_id
      @api_key = api_key
      @base_url = base_url
    end
  end

  # Main client for interacting with the CloudContactAI API
  class Client
    attr_reader :config, :sms, :mms

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

    # Get the base URL
    #
    # @return [String] Base URL
    def base_url
      @config.base_url
    end

    # Make an authenticated API request to the CCAI API
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
          JSON.parse(response.body)
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
