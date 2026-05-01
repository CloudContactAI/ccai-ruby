# frozen_string_literal: true

# Copyright (c) 2025 CloudContactAI LLC
# Licensed under the MIT License. See LICENSE in the project root for license information.

require 'test_helper'
require 'digest'
require 'tmpdir'

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
    temp_file = File.join(Dir.tmpdir, 'ccai_test_mms.jpg')
    File.write(temp_file, 'test image content')

    md5_hash = Digest::MD5.file(temp_file).hexdigest
    expected_file_key = "#{@client_id}/campaign/#{md5_hash}.jpg"

    # Step 1: checkFileUploaded returns empty (file not cached)
    stub_request(:get, "#{@client.base_url}/clients/#{@client_id}/storedUrl?fileKey=#{expected_file_key}")
      .to_return(
        status: 200,
        body: { storedUrl: '' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # Step 2: get signed upload URL
    stub_request(:post, "https://files.cloudcontactai.com/upload/url")
      .to_return(
        status: 200,
        body: { signedS3Url: @signed_url, fileKey: expected_file_key }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # Step 3: upload image
    stub_request(:put, @signed_url)
      .to_return(status: 200)

    # Step 4: send MMS
    stub_request(:post, "#{@client.base_url}/clients/#{@client_id}/campaigns/direct")
      .to_return(
        status: 200,
        body: { id: 'msg-123', status: 'sent', campaignId: 'camp-456', messagesSent: 1 }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    progress_updates = []
    options = CCAI::SMS::Options.new(
      on_progress: ->(status) { progress_updates << status }
    )

    response = @client.mms.send_with_image(
      temp_file,
      'image/jpeg',
      [@account],
      @message,
      @title,
      options
    )

    assert_equal 'msg-123', response.id
    assert_equal 'sent', response.status
    assert_equal 'camp-456', response.campaign_id

    assert_includes progress_updates, 'Checking if image already uploaded'
    assert_includes progress_updates, 'Getting signed upload URL'
    assert_includes progress_updates, 'Uploading image to S3'
    assert_includes progress_updates, 'Image uploaded successfully, sending MMS'

    File.delete(temp_file) if File.exist?(temp_file)
  end

  def test_send_with_image_cache_hit
    temp_file = File.join(Dir.tmpdir, 'ccai_test_mms_cache.jpg')
    File.write(temp_file, 'test image content')

    md5_hash = Digest::MD5.file(temp_file).hexdigest
    expected_file_key = "#{@client_id}/campaign/#{md5_hash}.jpg"

    # checkFileUploaded returns existing URL (cache hit)
    stub_request(:get, "#{@client.base_url}/clients/#{@client_id}/storedUrl?fileKey=#{expected_file_key}")
      .to_return(
        status: 200,
        body: { storedUrl: "https://s3.amazonaws.com/bucket/#{md5_hash}.jpg" }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # send MMS — only HTTP call expected (no upload)
    stub_request(:post, "#{@client.base_url}/clients/#{@client_id}/campaigns/direct")
      .to_return(
        status: 200,
        body: { id: 'msg-789', status: 'sent', campaignId: 'camp-999' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    progress_updates = []
    options = CCAI::SMS::Options.new(
      on_progress: ->(status) { progress_updates << status }
    )

    response = @client.mms.send_with_image(
      temp_file,
      'image/jpeg',
      [@account],
      @message,
      @title,
      options
    )

    assert_equal 'msg-789', response.id
    assert_equal 'sent', response.status

    assert_includes progress_updates, 'Checking if image already uploaded'
    assert_includes progress_updates, 'Image already exists in S3, sending MMS'
    refute_includes progress_updates, 'Getting signed upload URL'
    refute_includes progress_updates, 'Uploading image to S3'

    File.delete(temp_file) if File.exist?(temp_file)
  end

  def test_send_with_image_upload_failure
    temp_file = File.join(Dir.tmpdir, 'ccai_test_mms_fail.jpg')
    File.write(temp_file, 'test image content')

    md5_hash = Digest::MD5.file(temp_file).hexdigest
    expected_file_key = "#{@client_id}/campaign/#{md5_hash}.jpg"

    # checkFileUploaded returns empty
    stub_request(:get, "#{@client.base_url}/clients/#{@client_id}/storedUrl?fileKey=#{expected_file_key}")
      .to_return(
        status: 200,
        body: { storedUrl: '' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # get signed URL
    stub_request(:post, "https://files.cloudcontactai.com/upload/url")
      .to_return(
        status: 200,
        body: { signedS3Url: @signed_url, fileKey: expected_file_key }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # upload fails
    stub_request(:put, @signed_url)
      .to_return(status: 500)

    assert_raises CCAI::Error do
      @client.mms.send_with_image(
        temp_file,
        'image/jpeg',
        [@account],
        @message,
        @title
      )
    end

    File.delete(temp_file) if File.exist?(temp_file)
  end

  def test_check_file_uploaded
    file_key = "#{@client_id}/campaign/test.jpg"
    stub_request(:get, "#{@client.base_url}/clients/#{@client_id}/storedUrl?fileKey=#{file_key}")
      .to_return(
        status: 200,
        body: { storedUrl: 'https://s3.amazonaws.com/bucket/test.jpg' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @client.mms.check_file_uploaded(file_key)
    assert_equal 'https://s3.amazonaws.com/bucket/test.jpg', result['storedUrl']
  end

  def test_check_file_uploaded_on_error
    file_key = "#{@client_id}/campaign/nonexistent.jpg"
    stub_request(:get, "#{@client.base_url}/clients/#{@client_id}/storedUrl?fileKey=#{file_key}")
      .to_return(status: 404, body: '{}', headers: { 'Content-Type' => 'application/json' })

    # 404 triggers Faraday::Error -> CCAI::Error -> rescue returns {storedUrl: ''}
    # Actually 404 will raise CCAI::Error which is rescued
    result = @client.mms.check_file_uploaded(file_key)
    assert_equal '', result['storedUrl']
  end
end
