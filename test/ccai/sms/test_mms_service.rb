# frozen_string_literal: true

# Copyright (c) 2025 CloudContactAI LLC
# Licensed under the MIT License. See LICENSE in the project root for license information.

require 'test_helper'

class TestMMSService < Minitest::Test
  def setup
    @client_id = 'test-client-id'
    @api_key = 'test-api-key'
    @client = CCAI.new(client_id: @client_id, api_key: @api_key)
    
    @account = CCAI::SMS::Account.new(
      first_name: 'John',
      last_name: 'Doe',
      phone: '+15551234567'
    )
    
    @message = 'Hello ${firstName}, check out this image!'
    @title = 'Test MMS Campaign'
    @picture_file_key = "#{@client_id}/campaign/test-image.jpg"
    @file_name = 'test-image.jpg'
    @file_path = '/path/to/test-image.jpg'
    @content_type = 'image/jpeg'
    @signed_url = 'https://s3.amazonaws.com/bucket/signed-url'
  end

  def test_get_signed_upload_url
    stub_request(:post, "https://files.cloudcontactai.com/upload/url")
      .with(
        body: {
          fileName: @file_name,
          fileType: @content_type,
          fileBasePath: "#{@client_id}/campaign",
          publicFile: true
        }.to_json,
        headers: {
          'Authorization' => "Bearer #{@api_key}",
          'Content-Type' => 'application/json'
        }
      )
      .to_return(
        status: 200,
        body: {
          signedS3Url: @signed_url,
          fileKey: 'original/file/key'
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    
    response = @client.mms.get_signed_upload_url(@file_name, @content_type)
    
    assert_equal @signed_url, response.signed_s3_url
    assert_equal @picture_file_key, response.file_key
  end

  def test_get_signed_upload_url_with_empty_file_name
    assert_raises ArgumentError do
      @client.mms.get_signed_upload_url('', @content_type)
    end
  end

  def test_get_signed_upload_url_with_empty_file_type
    assert_raises ArgumentError do
      @client.mms.get_signed_upload_url(@file_name, '')
    end
  end

  def test_upload_image_to_signed_url
    # Mock File.exist? and File.binread
    File.stub :exist?, true do
      File.stub :binread, 'test image data' do
        stub_request(:put, @signed_url)
          .with(
            body: 'test image data',
            headers: {
              'Content-Type' => @content_type
            }
          )
          .to_return(status: 200)
        
        result = @client.mms.upload_image_to_signed_url(@signed_url, @file_path, @content_type)
        
        assert result
      end
    end
  end

  def test_upload_image_to_signed_url_with_empty_signed_url
    assert_raises ArgumentError do
      @client.mms.upload_image_to_signed_url('', @file_path, @content_type)
    end
  end

  def test_upload_image_to_signed_url_with_empty_file_path
    assert_raises ArgumentError do
      @client.mms.upload_image_to_signed_url(@signed_url, '', @content_type)
    end
  end

  def test_upload_image_to_signed_url_with_empty_content_type
    assert_raises ArgumentError do
      @client.mms.upload_image_to_signed_url(@signed_url, @file_path, '')
    end
  end

  def test_upload_image_to_signed_url_with_nonexistent_file
    File.stub :exist?, false do
      assert_raises ArgumentError do
        @client.mms.upload_image_to_signed_url(@signed_url, @file_path, @content_type)
      end
    end
  end

  def test_send_with_valid_inputs
    stub_request(:post, "#{@client.base_url}/clients/#{@client_id}/campaigns/direct")
      .with(
        body: {
          pictureFileKey: @picture_file_key,
          accounts: [
            {
              firstName: 'John',
              lastName: 'Doe',
              phone: '+15551234567'
            }
          ],
          message: @message,
          title: @title
        }.to_json,
        headers: {
          'Authorization' => "Bearer #{@api_key}",
          'Content-Type' => 'application/json',
          'Accept' => '*/*',
          'ForceNewCampaign' => 'true'
        }
      )
      .to_return(
        status: 200,
        body: {
          id: 'msg-123',
          status: 'sent',
          campaignId: 'camp-456',
          messagesSent: 1,
          timestamp: '2025-06-06T12:00:00Z'
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    
    response = @client.mms.send(@picture_file_key, [@account], @message, @title)
    
    assert_equal 'msg-123', response.id
    assert_equal 'sent', response.status
    assert_equal 'camp-456', response.campaign_id
    assert_equal 1, response.messages_sent
    assert_equal '2025-06-06T12:00:00Z', response.timestamp
  end

  def test_send_with_empty_picture_file_key
    assert_raises ArgumentError do
      @client.mms.send('', [@account], @message, @title)
    end
  end

  def test_send_with_empty_accounts
    assert_raises ArgumentError do
      @client.mms.send(@picture_file_key, [], @message, @title)
    end
  end

  def test_send_with_empty_message
    assert_raises ArgumentError do
      @client.mms.send(@picture_file_key, [@account], '', @title)
    end
  end

  def test_send_with_empty_title
    assert_raises ArgumentError do
      @client.mms.send(@picture_file_key, [@account], @message, '')
    end
  end

  def test_send_with_progress_tracking
    stub_request(:post, "#{@client.base_url}/clients/#{@client_id}/campaigns/direct")
      .to_return(
        status: 200,
        body: { id: 'msg-123', status: 'sent' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    
    progress_updates = []
    options = CCAI::SMS::Options.new(
      on_progress: ->(status) { progress_updates << status }
    )
    
    @client.mms.send(@picture_file_key, [@account], @message, @title, options)
    
    assert_equal 3, progress_updates.size
    assert_equal 'Preparing to send MMS', progress_updates[0]
    assert_equal 'Sending MMS', progress_updates[1]
    assert_equal 'MMS sent successfully', progress_updates[2]
  end

  def test_send_single
    stub_request(:post, "#{@client.base_url}/clients/#{@client_id}/campaigns/direct")
      .with(
        body: {
          pictureFileKey: @picture_file_key,
          accounts: [
            {
              firstName: 'Jane',
              lastName: 'Smith',
              phone: '+15559876543'
            }
          ],
          message: 'Hi ${firstName}, check out this image!',
          title: 'Single MMS Test'
        }.to_json
      )
      .to_return(
        status: 200,
        body: { id: 'msg-123', status: 'sent' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    
    response = @client.mms.send_single(
      @picture_file_key,
      'Jane',
      'Smith',
      '+15559876543',
      'Hi ${firstName}, check out this image!',
      'Single MMS Test'
    )
    
    assert_equal 'msg-123', response.id
    assert_equal 'sent', response.status
  end

  def test_send_with_image
    # Mock the component methods
    mock_upload_response = CCAI::SMS::SignedUrlResponse.new({
      'signedS3Url' => @signed_url,
      'fileKey' => @picture_file_key
    })
    
    mock_send_response = CCAI::SMS::Response.new({
      'id' => 'msg-123',
      'status' => 'sent',
      'campaignId' => 'camp-456',
      'messagesSent' => 1
    })
    
    # Create a mock MMS service
    mock_mms = Minitest::Mock.new
    
    # Set up expectations
    mock_mms.expect :get_signed_upload_url, mock_upload_response, [@file_name, @content_type]
    mock_mms.expect :upload_image_to_signed_url, true, [@signed_url, @file_path, @content_type]
    mock_mms.expect :send, mock_send_response, [@picture_file_key, [@account], @message, @title, nil, true]
    
    # Replace the real methods with mocks
    @client.mms.stub :get_signed_upload_url, mock_mms.method(:get_signed_upload_url) do
      @client.mms.stub :upload_image_to_signed_url, mock_mms.method(:upload_image_to_signed_url) do
        @client.mms.stub :send, mock_mms.method(:send) do
          # Test with progress tracking
          progress_updates = []
          options = CCAI::SMS::Options.new(
            on_progress: ->(status) { progress_updates << status }
          )
          
          # Call the method under test
          File.stub :basename, @file_name do
            response = @client.mms.send_with_image(
              @file_path,
              @content_type,
              [@account],
              @message,
              @title,
              options
            )
            
            # Verify the response
            assert_equal 'msg-123', response.id
            assert_equal 'sent', response.status
            assert_equal 'camp-456', response.campaign_id
            assert_equal 1, response.messages_sent
            
            # Verify progress updates
            assert_equal 3, progress_updates.size
            assert_equal 'Getting signed upload URL', progress_updates[0]
            assert_equal 'Uploading image to S3', progress_updates[1]
            assert_equal 'Image uploaded successfully, sending MMS', progress_updates[2]
          end
        end
      end
    end
    
    # Verify all expectations were met
    mock_mms.verify
  end

  def test_send_with_image_upload_failure
    # Mock the component methods
    mock_upload_response = CCAI::SMS::SignedUrlResponse.new({
      'signedS3Url' => @signed_url,
      'fileKey' => @picture_file_key
    })
    
    # Create a mock MMS service
    mock_mms = Minitest::Mock.new
    
    # Set up expectations
    mock_mms.expect :get_signed_upload_url, mock_upload_response, [@file_name, @content_type]
    mock_mms.expect :upload_image_to_signed_url, false, [@signed_url, @file_path, @content_type]
    
    # Replace the real methods with mocks
    @client.mms.stub :get_signed_upload_url, mock_mms.method(:get_signed_upload_url) do
      @client.mms.stub :upload_image_to_signed_url, mock_mms.method(:upload_image_to_signed_url) do
        # Call the method under test
        File.stub :basename, @file_name do
          assert_raises CCAI::Error do
            @client.mms.send_with_image(
              @file_path,
              @content_type,
              [@account],
              @message,
              @title
            )
          end
        end
      end
    end
    
    # Verify all expectations were met
    mock_mms.verify
  end
end
