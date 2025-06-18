#!/usr/bin/env ruby
# frozen_string_literal: true

# Copyright (c) 2025 CloudContactAI LLC
# Licensed under the MIT License. See LICENSE in the project root for license information.

require 'ccai'

# Initialize the client
client = CCAI.new(
  client_id: 'YOUR-CLIENT-ID',
  api_key: 'YOUR-API-KEY'
)

# Example 1: Complete MMS workflow (get URL, upload image, send MMS)
def send_mms_with_image(client)
  puts "=== Example 1: Complete MMS workflow ==="
  
  # Path to your image file
  image_path = 'path/to/your/image.jpg'
  content_type = 'image/jpeg'
  
  # Define recipient
  account = CCAI::SMS::Account.new(
    first_name: 'John',
    last_name: 'Doe',
    phone: '+15551234567'  # Use E.164 format
  )
  
  # Message content and campaign title
  message = 'Hello ${firstName}, check out this image!'
  title = 'MMS Campaign Example'
  
  # Define progress tracking
  progress_updates = []
  options = CCAI::SMS::Options.new(
    timeout: 60,
    on_progress: ->(status) {
      puts "Progress: #{status}"
      progress_updates << status
    }
  )
  
  # Send MMS with image in one step
  begin
    response = client.mms.send_with_image(
      image_path,
      content_type,
      [account],
      message,
      title,
      options
    )
    
    puts "MMS sent! Campaign ID: #{response.campaign_id}"
    puts "Messages sent: #{response.messages_sent}"
    puts "Status: #{response.status}"
  rescue => e
    puts "Error sending MMS: #{e.message}"
  end
end

# Example 2: Step-by-step MMS workflow
def send_mms_step_by_step(client)
  puts "\n=== Example 2: Step-by-step MMS workflow ==="
  
  # Path to your image file
  image_path = 'path/to/your/image.jpg'
  file_name = File.basename(image_path)
  content_type = 'image/jpeg'
  
  begin
    # Step 1: Get a signed URL for uploading
    puts "Getting signed upload URL..."
    upload_response = client.mms.get_signed_upload_url(
      file_name,
      content_type
    )
    
    signed_url = upload_response.signed_s3_url
    file_key = upload_response.file_key
    
    puts "Got signed URL: #{signed_url}"
    puts "File key: #{file_key}"
    
    # Step 2: Upload the image to the signed URL
    puts "Uploading image..."
    upload_success = client.mms.upload_image_to_signed_url(
      signed_url,
      image_path,
      content_type
    )
    
    unless upload_success
      puts "Failed to upload image"
      return
    end
    
    puts "Image uploaded successfully"
    
    # Step 3: Send the MMS with the uploaded image
    puts "Sending MMS..."
    
    # Define recipients
    accounts = [
      CCAI::SMS::Account.new(
        first_name: 'John',
        last_name: 'Doe',
        phone: '+15551234567'
      ),
      CCAI::SMS::Account.new(
        first_name: 'Jane',
        last_name: 'Smith',
        phone: '+15559876543'
      )
    ]
    
    # Message content and campaign title
    message = 'Hello ${firstName}, check out this image!'
    title = 'MMS Campaign Example'
    
    # Send the MMS
    response = client.mms.send(
      file_key,
      accounts,
      message,
      title
    )
    
    puts "MMS sent! Campaign ID: #{response.campaign_id}"
    puts "Messages sent: #{response.messages_sent}"
    puts "Status: #{response.status}"
  rescue => e
    puts "Error in MMS workflow: #{e.message}"
  end
end

# Example 3: Send a single MMS
def send_single_mms(client)
  puts "\n=== Example 3: Send a single MMS ==="
  
  begin
    # Define the file key of an already uploaded image
    picture_file_key = "your-client-id/campaign/your-image.jpg"
    
    # Send a single MMS
    response = client.mms.send_single(
      picture_file_key,
      'John',
      'Doe',
      '+15551234567',
      'Hello ${firstName}, check out this image!',
      'Single MMS Example'
    )
    
    puts "MMS sent! Campaign ID: #{response.campaign_id}"
    puts "Status: #{response.status}"
  rescue => e
    puts "Error sending single MMS: #{e.message}"
  end
end

# Run all examples
send_mms_with_image(client)
send_mms_step_by_step(client)
send_single_mms(client)
