# frozen_string_literal: true

# Copyright (c) 2025 CloudContactAI LLC
# Licensed under the MIT License. See LICENSE in the project root for license information.

require 'faraday/multipart'
require 'ccai/sms/models'

module CCAI
  module SMS
    # MMS service for sending multimedia messages through the CCAI API
    class MMSService
      # Create a new MMS service instance
      #
      # @param client [CCAI::Client] The parent CCAI client
      def initialize(client)
        @client = client
        @http_client = Faraday.new do |conn|
          conn.headers['Authorization'] = "Bearer #{client.api_key}"
          conn.request :multipart
        end
      end

      # Get a signed S3 URL to upload an image file
      #
      # @param file_name [String] Name of the file to upload
      # @param file_type [String] MIME type of the file
      # @param file_base_path [String, nil] Base path for the file in S3 (default: clientId/campaign)
      # @param public_file [Boolean] Whether the file should be public (default: true)
      # @return [CCAI::SMS::SignedUrlResponse] Response containing the signed URL and file key
      # @raise [ArgumentError] If required parameters are missing or invalid
      # @raise [CCAI::Error] If the API request fails
      def get_signed_upload_url(file_name, file_type, file_base_path = nil, public_file = true)
        raise ArgumentError, 'File name is required' if file_name.nil? || file_name.empty?
        raise ArgumentError, 'File type is required' if file_type.nil? || file_type.empty?

        # Use default file_base_path if not provided
        file_base_path ||= "#{@client.client_id}/campaign"

        # Define file_key explicitly as clientId/campaign/filename
        file_key = "#{@client.client_id}/campaign/#{file_name}"

        data = {
          fileName: file_name,
          fileType: file_type,
          fileBasePath: file_base_path,
          publicFile: public_file
        }

        begin
          response = @http_client.post(
            'https://files.cloudcontactai.com/upload/url',
            data.to_json,
            'Content-Type' => 'application/json'
          )

          if response.success?
            response_data = JSON.parse(response.body)
            
            if response_data['signedS3Url'].nil?
              raise CCAI::Error.new('Invalid response from upload URL API')
            end
            
            # Override the fileKey with our explicitly defined one
            response_data['fileKey'] = file_key
            
            SignedUrlResponse.new(response_data)
          else
            raise CCAI::Error.new("API Error: #{response.status} - #{response.body}")
          end
        rescue Faraday::Error => e
          raise CCAI::Error.new("Failed to get signed upload URL: #{e.message}")
        end
      end

      # Upload an image file to a signed S3 URL
      #
      # @param signed_url [String] The signed S3 URL to upload to
      # @param file_path [String] Path to the file to upload
      # @param content_type [String] MIME type of the file
      # @return [Boolean] True if upload was successful
      # @raise [ArgumentError] If required parameters are missing or invalid
      # @raise [CCAI::Error] If the file upload fails
      def upload_image_to_signed_url(signed_url, file_path, content_type)
        raise ArgumentError, 'Signed URL is required' if signed_url.nil? || signed_url.empty?
        raise ArgumentError, 'File path is required' if file_path.nil? || file_path.empty?
        raise ArgumentError, "File does not exist: #{file_path}" unless File.exist?(file_path)
        raise ArgumentError, 'Content type is required' if content_type.nil? || content_type.empty?

        begin
          file_content = File.binread(file_path)
          
          response = @http_client.put(
            signed_url,
            file_content,
            'Content-Type' => content_type
          )
          
          response.success?
        rescue => e
          raise CCAI::Error.new("Failed to upload file: #{e.message}")
        end
      end

      # Send an MMS message to one or more recipients
      #
      # @param picture_file_key [String] S3 file key for the image
      # @param accounts [Array<CCAI::SMS::Account>] List of recipient accounts
      # @param message [String] Message content (can include ${firstName} and ${lastName} variables)
      # @param title [String] Campaign title
      # @param options [CCAI::SMS::Options, nil] Optional settings for the MMS send operation
      # @param force_new_campaign [Boolean] Whether to force a new campaign (default: true)
      # @return [CCAI::SMS::Response] API response
      # @raise [ArgumentError] If required parameters are missing or invalid
      def send(picture_file_key, accounts, message, title, options = nil, force_new_campaign = true)
        # Validate inputs
        raise ArgumentError, 'Picture file key is required' if picture_file_key.nil? || picture_file_key.empty?
        raise ArgumentError, 'At least one account is required' if accounts.nil? || accounts.empty?
        raise ArgumentError, 'Message is required' if message.nil? || message.empty?
        raise ArgumentError, 'Title is required' if title.nil? || title.empty?

        # Create options if not provided
        options ||= Options.new

        # Notify progress if callback provided
        options.notify_progress('Preparing to send MMS')

        # Prepare the endpoint and data
        endpoint = "/clients/#{@client.client_id}/campaigns/direct"

        # Convert Account objects to hashes for API compatibility
        accounts_data = accounts.map(&:to_hash)

        campaign_data = {
          pictureFileKey: picture_file_key,
          accounts: accounts_data,
          message: message,
          title: title
        }

        # Set up headers for force new campaign if needed
        headers = force_new_campaign ? { 'ForceNewCampaign' => 'true' } : nil

        begin
          # Notify progress if callback provided
          options.notify_progress('Sending MMS')

          # Make the API request
          response_data = @client.request(:post, endpoint, campaign_data, headers)

          # Notify progress if callback provided
          options.notify_progress('MMS sent successfully')

          # Convert response to Response object
          Response.new(response_data)
        rescue => e
          # Notify progress if callback provided
          options.notify_progress('MMS sending failed')

          raise e
        end
      end

      # Send a single MMS message to one recipient
      #
      # @param picture_file_key [String] S3 file key for the image
      # @param first_name [String] Recipient's first name
      # @param last_name [String] Recipient's last name
      # @param phone [String] Recipient's phone number (E.164 format)
      # @param message [String] Message content (can include ${firstName} and ${lastName} variables)
      # @param title [String] Campaign title
      # @param options [CCAI::SMS::Options, nil] Optional settings for the MMS send operation
      # @param force_new_campaign [Boolean] Whether to force a new campaign (default: true)
      # @return [CCAI::SMS::Response] API response
      def send_single(picture_file_key, first_name, last_name, phone, message, title, options = nil, force_new_campaign = true)
        account = Account.new(
          first_name: first_name,
          last_name: last_name,
          phone: phone
        )

        send(picture_file_key, [account], message, title, options, force_new_campaign)
      end

      # Complete MMS workflow: get signed URL, upload image, and send MMS
      #
      # @param image_path [String] Path to the image file
      # @param content_type [String] MIME type of the image
      # @param accounts [Array<CCAI::SMS::Account>] List of recipient accounts
      # @param message [String] Message content (can include ${firstName} and ${lastName} variables)
      # @param title [String] Campaign title
      # @param options [CCAI::SMS::Options, nil] Optional settings for the MMS send operation
      # @param force_new_campaign [Boolean] Whether to force a new campaign (default: true)
      # @return [CCAI::SMS::Response] API response
      # @raise [ArgumentError] If required parameters are missing or invalid
      # @raise [CCAI::Error] If any step of the process fails
      def send_with_image(image_path, content_type, accounts, message, title, options = nil, force_new_campaign = true)
        # Create options if not provided
        options ||= Options.new

        # Step 1: Get the file name from the path
        file_name = File.basename(image_path)

        # Notify progress if callback provided
        options.notify_progress('Getting signed upload URL')

        # Step 2: Get a signed URL for uploading
        upload_response = get_signed_upload_url(file_name, content_type)
        signed_url = upload_response.signed_s3_url
        file_key = upload_response.file_key

        # Notify progress if callback provided
        options.notify_progress('Uploading image to S3')

        # Step 3: Upload the image to the signed URL
        upload_success = upload_image_to_signed_url(signed_url, image_path, content_type)

        unless upload_success
          raise CCAI::Error.new('Failed to upload image to S3')
        end

        # Notify progress if callback provided
        options.notify_progress('Image uploaded successfully, sending MMS')

        # Step 4: Send the MMS with the uploaded image
        send(file_key, accounts, message, title, options, force_new_campaign)
      end
    end
  end
end
