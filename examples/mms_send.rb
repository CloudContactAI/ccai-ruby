#!/usr/bin/env ruby
# frozen_string_literal: true

# Copyright (c) 2025 CloudContactAI LLC
# Licensed under the MIT License. See LICENSE in the project root for license information.

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'ccai'

# Initialize the client
client = CCAI.new(
  client_id: '2682',
  api_key: 'eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJpbmZvQGFsbGNvZGUuY29tIiwiaXNzIjoiY2xvdWRjb250YWN0IiwibmJmIjoxNzE5NDQwMjM2LCJpYXQiOjE3MTk0NDAyMzYsInJvbGUiOiJVU0VSIiwiY2xpZW50SWQiOjI2ODIsImlkIjoyNzY0LCJ0eXBlIjoiQVBJX0tFWSIsImtleV9yYW5kb21faWQiOiI1MGRiOTUzZC1hMjUxLTRmZjMtODI5Yi01NjIyOGRhOGE1YTAifQ.PKVjXYHdjBMum9cTgLzFeY2KIb9b2tjawJ0WXalsb8Bckw1RuxeiYKS1bw5Cc36_Rfmivze0T7r-Zy0PVj2omDLq65io0zkBzIEJRNGDn3gx_AqmBrJ3yGnz9s0WTMr2-F1TFPUByzbj1eSOASIKeI7DGufTA5LDrRclVkz32Oo'
)

# Define recipient
account = CCAI::SMS::Account.new(
  first_name: 'John',
  last_name: 'Doe',
  phone: '+14156961732'
)

# Image path and content type
image_path = File.expand_path('../imageRUBY.jpg', __dir__)
content_type = 'image/jpeg'

# Check if image exists
unless File.exist?(image_path)
  puts "Error: Image file not found at #{image_path}"
  exit 1
end

puts "Image found at: #{image_path}"

# Step-by-step MMS workflow with detailed error handling
begin
  # Step 1: Get signed URL
  puts "Step 1: Getting signed upload URL..."
  upload_response = client.mms.get_signed_upload_url(
    'imageRUBY.jpg',
    content_type
  )
  
  signed_url = upload_response.signed_s3_url
  file_key = upload_response.file_key
  puts "Got signed URL and file key: #{file_key}"
  
  # Step 2: Upload image with manual HTTP client for debugging
  puts "Step 2: Uploading image to S3..."
  begin
    file_content = File.binread(image_path)
    puts "File size: #{file_content.length} bytes"
    
    # Create a new HTTP client for the upload
    upload_client = Faraday.new do |conn|
      conn.adapter Faraday.default_adapter
    end
    
    response = upload_client.put(
      signed_url,
      file_content,
      'Content-Type' => content_type
    )
    
    puts "Upload response status: #{response.status}"
    puts "Upload response body: #{response.body}" unless response.body.empty?
    
    if response.success?
      puts "Image uploaded successfully!"
      
      # Step 3: Send MMS
      puts "Step 3: Sending MMS..."
      mms_response = client.mms.send(
        file_key,
        [account],
        'Hello ${firstName}, check out this Ruby image!',
        'MMS Ruby Example'
      )
      
      puts "MMS sent! Campaign ID: #{mms_response.campaign_id}"
    else
      puts "Failed to upload image to S3 - HTTP status: #{response.status}"
    end
  rescue => upload_error
    puts "Upload error: #{upload_error.message}"
    puts "Upload backtrace: #{upload_error.backtrace.first(3).join("\n")}"
  end
  
rescue => e
  puts "Error: #{e.message}"
  puts "Backtrace: #{e.backtrace.first(5).join("\n")}"
end