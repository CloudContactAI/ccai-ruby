# frozen_string_literal: true

# Copyright (c) 2025 CloudContactAI LLC
# Licensed under the MIT License. See LICENSE in the project root for license information.

module CCAI
  module Campaign
    # Service for managing Campaigns (10DLC compliance)
    class CampaignService
      # Create a new CampaignService instance
      #
      # @param client [CCAI::Client] The parent CCAI client
      def initialize(client)
        @client = client
      end

      # Create a new campaign
      #
      # @param campaign [Hash] Campaign attributes
      # @return [Hash] API response
      def create(campaign)
        validate!(campaign, is_create: true)
        @client.compliance_request(:post, '/v1/campaigns', campaign)
      end

      # Get a campaign by ID
      #
      # @param campaign_id [String] Campaign ID
      # @return [Hash] API response
      def get(campaign_id)
        raise ArgumentError, 'campaignId is required' if campaign_id.nil? || campaign_id.to_s.empty?

        @client.compliance_request(:get, "/v1/campaigns/#{campaign_id}")
      end

      # List all campaigns for the account
      #
      # @return [Hash] API response
      def list
        @client.compliance_request(:get, '/v1/campaigns')
      end

      # Update a campaign
      #
      # @param campaign_id [String] Campaign ID
      # @param campaign [Hash] Updated campaign attributes
      # @return [Hash] API response
      def update(campaign_id, campaign)
        raise ArgumentError, 'campaignId is required' if campaign_id.nil? || campaign_id.to_s.empty?

        validate!(campaign, is_create: false)
        @client.compliance_request(:patch, "/v1/campaigns/#{campaign_id}", campaign)
      end

      # Delete a campaign
      #
      # @param campaign_id [String] Campaign ID
      # @return [Hash] API response
      def delete(campaign_id)
        raise ArgumentError, 'campaignId is required' if campaign_id.nil? || campaign_id.to_s.empty?

        @client.compliance_request(:delete, "/v1/campaigns/#{campaign_id}")
      end

      private

      REQUIRED_CREATE_FIELDS = %i[
        brandId useCase description messageFlow
        hasEmbeddedLinks hasEmbeddedPhone isAgeGated isDirectLending
        optInKeywords optInMessage optInProofUrl
        helpKeywords helpMessage
        optOutKeywords optOutMessage
        sampleMessages
      ].freeze

      def validate!(campaign, is_create: true)
        if is_create
          REQUIRED_CREATE_FIELDS.each do |field|
            val = campaign.key?(field) ? campaign[field] : campaign[field.to_s]
            raise ArgumentError, "#{field} is required" if val.nil?
          end

          brand_id = campaign.key?(:brandId) ? campaign[:brandId] : campaign['brandId']
          raise ArgumentError, 'brandId is required' if brand_id.to_s.strip.empty?
        end

        sample_messages = campaign.key?(:sampleMessages) ? campaign[:sampleMessages] : campaign['sampleMessages']
        if sample_messages
          unless sample_messages.is_a?(Array) && sample_messages.length.between?(2, 5)
            raise ArgumentError, 'sampleMessages must have between 2 and 5 items'
          end

          opt_out_keywords = (campaign[:optOutKeywords] || campaign['optOutKeywords'] || []).map(&:upcase)
          help_keywords    = (campaign[:helpKeywords]   || campaign['helpKeywords']   || []).map(&:upcase)

          has_stop = sample_messages.any? do |m|
            msg = m.to_s.upcase
            msg.include?('REPLY STOP') || opt_out_keywords.any? { |kw| msg.include?("REPLY #{kw}") }
          end
          raise ArgumentError, 'at least one sampleMessage must contain "Reply STOP" or an optOutKeyword' unless has_stop

          has_help = sample_messages.any? do |m|
            msg = m.to_s.upcase
            msg.include?('REPLY HELP') || help_keywords.any? { |kw| msg.include?("REPLY #{kw}") }
          end
          raise ArgumentError, 'at least one sampleMessage must contain "Reply HELP" or a helpKeyword' unless has_help
        end

        opt_out_msg = campaign[:optOutMessage] || campaign['optOutMessage']
        if opt_out_msg
          opt_out_keywords = (campaign[:optOutKeywords] || campaign['optOutKeywords'] || []).map(&:upcase)
          unless opt_out_msg.to_s.upcase.include?('STOP') || opt_out_keywords.any? { |kw| opt_out_msg.to_s.upcase.include?(kw) }
            raise ArgumentError, 'optOutMessage must contain "STOP" or an optOutKeyword'
          end
        end

        use_case = campaign[:useCase] || campaign['useCase']
        if use_case && %w[MIXED LOW_VOLUME_MIXED].include?(use_case.to_s)
          sub_use_cases = campaign[:subUseCases] || campaign['subUseCases']
          unless sub_use_cases.is_a?(Array) && sub_use_cases.length.between?(2, 3)
            raise ArgumentError, 'MIXED/LOW_VOLUME_MIXED campaigns require 2-3 subUseCases'
          end
        end
      end
    end
  end
end
