# frozen_string_literal: true

# Copyright (c) 2025 CloudContactAI LLC
# Licensed under the MIT License. See LICENSE in the project root for license information.

module CCAI
  module Brand
    # Service for managing Brands (10DLC compliance)
    class BrandService
      # Create a new BrandService instance
      #
      # @param client [CCAI::Client] The parent CCAI client
      def initialize(client)
        @client = client
      end

      # Create a new brand
      #
      # @param brand [Hash] Brand attributes
      # @return [Hash] API response
      def create(brand)
        validate!(brand)
        @client.compliance_request(:post, '/v1/brands', brand)
      end

      # Get a brand by ID
      #
      # @param brand_id [String] Brand ID
      # @return [Hash] API response
      def get(brand_id)
        raise ArgumentError, 'brandId is required' if brand_id.nil? || brand_id.to_s.empty?

        @client.compliance_request(:get, "/v1/brands/#{brand_id}")
      end

      # List all brands for the account
      #
      # @return [Hash] API response
      def list
        @client.compliance_request(:get, '/v1/brands')
      end

      # Update a brand
      #
      # @param brand_id [String] Brand ID
      # @param brand [Hash] Updated brand attributes
      # @return [Hash] API response
      def update(brand_id, brand)
        raise ArgumentError, 'brandId is required' if brand_id.nil? || brand_id.to_s.empty?

        validate!(brand, is_create: false)
        @client.compliance_request(:patch, "/v1/brands/#{brand_id}", brand)
      end

      # Delete a brand
      #
      # @param brand_id [String] Brand ID
      # @return [Hash] API response
      def delete(brand_id)
        raise ArgumentError, 'brandId is required' if brand_id.nil? || brand_id.to_s.empty?

        @client.compliance_request(:delete, "/v1/brands/#{brand_id}")
      end

      private

      REQUIRED_CREATE_FIELDS = %i[
        legalCompanyName entityType taxId taxIdCountry country
        verticalType websiteUrl street city state postalCode
        contactFirstName contactLastName contactEmail contactPhone
      ].freeze

      def validate!(brand, is_create: true)
        if is_create
          REQUIRED_CREATE_FIELDS.each do |field|
            val = brand[field] || brand[field.to_s]
            raise ArgumentError, "#{field} is required" if val.nil? || val.to_s.strip.empty?
          end
        end

        entity_type = brand[:entityType] || brand['entityType']
        if entity_type == 'PUBLIC_PROFIT'
          stock_symbol   = brand[:stockSymbol]  || brand['stockSymbol']
          stock_exchange = brand[:stockExchange] || brand['stockExchange']
          if stock_symbol.nil? || stock_symbol.to_s.empty?
            raise ArgumentError, 'stockSymbol is required for PUBLIC_PROFIT entities'
          end
          if stock_exchange.nil? || stock_exchange.to_s.empty?
            raise ArgumentError, 'stockExchange is required for PUBLIC_PROFIT entities'
          end
        end

        website_url = brand[:websiteUrl] || brand['websiteUrl']
        if website_url && !website_url.to_s.match?(/^https?:\/\//)
          raise ArgumentError, 'websiteUrl must start with http:// or https://'
        end

        contact_email = brand[:contactEmail] || brand['contactEmail']
        if contact_email && !contact_email.to_s.match?(/\A[^@\s]+@[^@\s]+\.[^@\s]+\z/)
          raise ArgumentError, 'contactEmail must be a valid email address'
        end
      end
    end
  end
end
