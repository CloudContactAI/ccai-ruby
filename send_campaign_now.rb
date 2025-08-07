#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('lib', __dir__))
require 'ccai'
require 'faraday'
require 'json'

# Initialize the client
client = CCAI.new(
  client_id: '1231',
  api_key: 'eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJhbmRyZWFzQGFsbGNvZGUuY29tIiwiaXNzIjoiY2xvdWRjb250YWN0IiwibmJmIjoxNzUyMDg5MDk2LCJpYXQiOjE3NTIwODkwOTYsInJvbGUiOiJVU0VSIiwiY2xpZW50SWQiOjEyMzEsImlkIjoxMjIzLCJ0eXBlIjoiQVBJX0tFWSIsImtleV9yYW5kb21faWQiOiIzNTAxZjVmNC0zOWYyLTRjYzctYTk2Yi04ZDkyZjVlMjM5ZGUifQ.XjtDPpyYUJNJjLrpM1pdQ4Sqk90eaagqzPX2v1gwHDP1wOV4fTbB44UGDRXtWyGvN-Fz7o84_Ab-VlAjNCyEmXcDzmzscnwFSbqiZrWLAM_W3Mutd36vArl9QSG_osuYdf9T2wmAduUZu2bcnvKHdBbEaBUalJSSUoHwHsMBX3w'
)

# Try to send a campaign and then trigger it
puts "Creating and sending email campaign..."

campaign_data = {
  subject: 'CCAI Ruby - Immediate Send Test',
  title: 'Ruby Immediate Send Test',
  message: '<h1>Hello Andreas!</h1><p>This email should send immediately if we trigger it correctly.</p><p>Testing immediate send functionality.</p>',
  senderEmail: 'noreply@allcode.com',
  replyEmail: 'support@allcode.com',
  senderName: 'CCAI Ruby Client',
  accounts: [
    { firstName: 'Andreas', lastName: 'AllCode', email: 'andreas@allcode.com', phone: '' }
  ],
  campaignType: 'EMAIL',
  addToList: 'noList',
  contactInput: 'accounts',
  fromType: 'single',
  senders: [],
  # Try adding parameters that might trigger immediate sending
  scheduled: false,
  scheduledTimestamp: nil,
  scheduledTimezone: nil
}

begin
  # Create the campaign
  response = client.email.send_campaign(campaign_data)
  campaign_id = response['id']
  
  puts "✅ Campaign created: #{campaign_id}"
  puts "Status: #{response['status']}"
  
  # Try to trigger the campaign (this might be a separate endpoint)
  puts "\nAttempting to trigger campaign sending..."
  
  connection = Faraday.new do |conn|
    conn.headers['Authorization'] = "Bearer #{client.api_key}"
    conn.headers['Content-Type'] = 'application/json'
    conn.headers['Accept'] = '*/*'
    conn.headers['AccountId'] = '1223'
    conn.headers['ClientId'] = client.client_id
  end
  
  # Try different possible endpoints to trigger sending
  trigger_endpoints = [
    "/campaigns/#{campaign_id}/send",
    "/campaigns/#{campaign_id}/start",
    "/campaigns/#{campaign_id}/trigger",
    "/campaigns/#{campaign_id}/execute"
  ]
  
  base_url = 'https://email-campaigns-test-cloudcontactai.allcode.com/api/v1'
  
  trigger_endpoints.each do |endpoint|
    begin
      puts "Trying: POST #{endpoint}"
      trigger_response = connection.post("#{base_url}#{endpoint}")
      
      if trigger_response.success?
        puts "✅ Successfully triggered with #{endpoint}"
        puts "Response: #{trigger_response.body}"
        break
      else
        puts "❌ #{endpoint} failed: #{trigger_response.status}"
      end
    rescue => e
      puts "❌ #{endpoint} error: #{e.message}"
    end
  end
  
rescue => e
  puts "❌ Failed: #{e.message}"
end