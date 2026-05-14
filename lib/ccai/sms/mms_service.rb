# frozen_string_literal: true

# Copyright (c) 2025 CloudContactAI LLC
# Licensed under the MIT License. See LICENSE in the project root for license information.

require 'faraday/multipart'
require 'ccai/sms/models'
require 'digest'

module CCAI
  module SMS
    # MMS service for sending multimedia messages through the CCAI API
    class MMSService
      # Create a new MMS service instance
      #
      # @param client [CCAI::Client] The parent CCAI client
      def initialize(client)
        @client = client
        @upload_client = Faraday.new
        @api_client = Faraday.new do |conn|
          conn.headers['Authorization'] = "Bearer #{client.api_key}"
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
          response = @api_client.post(
            "#{@client.files_base_url}/upload/url",
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
          file_content.force_encoding(Encoding::BINARY)

          # Use raw HTTP PUT request directly (like Go and Node)
          require 'net/http'
          uri = URI(signed_url)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = uri.scheme == 'https'

          # Start connection and force binary mode on socket to prevent
          # CRLF conversion on Windows (LF -> CRLF corrupts binary data)
          http.start
          socket = http.instance_variable_get(:@socket)
          if socket
            raw_io = socket.io
            raw_io.binmode if raw_io.respond_to?(:binmode)
          end

          # Create request with full path including query parameters
          path = uri.path
          path += '?' + uri.query if uri.query
          
          request = Net::HTTP::Put.new(path)
          request['Content-Type'] = content_type
          request['Content-Length'] = file_content.bytesize.to_s
          request.body = file_content
          
          response = http.request(request)
          http.finish
          response.code.to_i >= 200 && response.code.to_i < 300
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
      # @param sender_phone [String, nil] Optional sender phone number
      # @param options [CCAI::SMS::Options, nil] Optional settings for the MMS send operation
      # @param force_new_campaign [Boolean] Whether to force a new campaign (default: true)
      # @return [CCAI::SMS::Response] API response
      # @raise [ArgumentError] If required parameters are missing or invalid
      def send(picture_file_key, accounts, message, title, sender_phone = nil, options = nil, force_new_campaign = true)
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
        campaign_data[:senderPhone] = sender_phone if sender_phone

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
      # @param custom_data [String, nil] Optional arbitrary string forwarded to your webhook handler (sent as messageData)
      # @param sender_phone [String, nil] Optional sender phone number
      # @param options [CCAI::SMS::Options, nil] Optional settings for the MMS send operation
      # @param force_new_campaign [Boolean] Whether to force a new campaign (default: true)
      # @return [CCAI::SMS::Response] API response
      def send_single(picture_file_key, first_name, last_name, phone, message, title, custom_data = nil, sender_phone = nil, options = nil, force_new_campaign = true)
        account = Account.new(
          first_name: first_name,
          last_name: last_name,
          phone: phone,
          custom_data: custom_data
        )

        send(picture_file_key, [account], message, title, sender_phone, options, force_new_campaign)
      end

      # Complete MMS workflow: get signed URL, upload image, and send MMS
      #
      # @param image_path [String] Path to the image file
      # @param content_type [String] MIME type of the image
      # @param accounts [Array<CCAI::SMS::Account>] List of recipient accounts
      # @param message [String] Message content (can include ${firstName} and ${lastName} variables)
      # @param title [String] Campaign title
      # @param sender_phone [String, nil] Optional sender phone number
      # @param options [CCAI::SMS::Options, nil] Optional settings for the MMS send operation
      # @param force_new_campaign [Boolean] Whether to force a new campaign (default: true)
      # @return [CCAI::SMS::Response] API response
      # @raise [ArgumentError] If required parameters are missing or invalid
      # @raise [CCAI::Error] If any step of the process fails
      def send_with_image(image_path, content_type, accounts, message, title, sender_phone = nil, options = nil, force_new_campaign = true)
        # Create options if not provided
        options ||= Options.new

        # Step 1: Compute MD5 of the image file for caching
        md5_image = md5_file(image_path)
        extension = File.extname(image_path).delete('.').downcase
        file_name = "#{md5_image}.#{extension}"
        file_key = "#{@client.client_id}/campaign/#{file_name}"

        # Step 2: Check if the same image has already been uploaded
        options.notify_progress('Checking if image already uploaded')
        stored_url_response = check_file_uploaded(file_key)

        stored_url = stored_url_response && (stored_url_response[:storedUrl] || stored_url_response['storedUrl'])
        if !stored_url.to_s.empty?
          # Image already uploaded, skip upload and send directly
          options.notify_progress('Image already exists in S3, sending MMS')
          return send(file_key, accounts, message, title, sender_phone, options, force_new_campaign)
        end

        # Step 3: Get a signed URL for uploading
        options.notify_progress('Getting signed upload URL')
        upload_response = get_signed_upload_url(file_name, content_type)
        signed_url = upload_response.signed_s3_url

        # Step 4: Upload the image to the signed URL
        options.notify_progress('Uploading image to S3')
        upload_success = upload_image_to_signed_url(signed_url, image_path, content_type)

        unless upload_success
          raise CCAI::Error.new('Failed to upload image to S3')
        end

        # Step 5: Send the MMS with the uploaded image
        options.notify_progress('Image uploaded successfully, sending MMS')
        send(file_key, accounts, message, title, sender_phone, options, force_new_campaign)
      end

      # Check if a file has already been uploaded to S3
      #
      # @param file_key [String] The S3 file key to check
      # @return [Hash, nil] Response containing storedUrl, or nil on error
      def check_file_uploaded(file_key)
        @client.request(:get, "/clients/#{@client.client_id}/storedUrl?fileKey=#{file_key}")
      rescue CCAI::Error
        { 'storedUrl' => '' }
      end

      private

      # Calculate the MD5 hash of a file
      #
      # @param file_path [String] Path to the file
      # @return [String] MD5 hash in hexadecimal format
      def md5_file(file_path)
        Digest::MD5.file(file_path).hexdigest
      end
    end
  end
end
