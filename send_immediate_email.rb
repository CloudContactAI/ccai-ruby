#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('lib', __dir__))
require 'ccai'

# Initialize the client
client = CCAI.new(
  client_id: '1231',
  api_key: 'eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJhbmRyZWFzQGFsbGNvZGUuY29tIiwiaXNzIjoiY2xvdWRjb250YWN0IiwibmJmIjoxNzUyMDg5MDk2LCJpYXQiOjE3NTIwODkwOTYsInJvbGUiOiJVU0VSIiwiY2xpZW50SWQiOjEyMzEsImlkIjoxMjIzLCJ0eXBlIjoiQVBJX0tFWSIsImtleV9yYW5kb21faWQiOiIzNTAxZjVmNC0zOWYyLTRjYzctYTk2Yi04ZDkyZjVlMjM5ZGUifQ.XjtDPpyYUJNJjLrpM1pdQ4Sqk90eaagqzPX2v1gwHDP1wOV4fTbB44UGDRXtWyGvN-Fz7o84_Ab-VlAjNCyEmXcDzmzscnwFSbqiZrWLAM_W3Mutd36vArl9QSG_osuYdf9T2wmAduUZu2bcnvKHdBbEaBUalJSSUoHwHsMBX3w'
)

puts "Sending email with immediate send parameters..."

# Try different parameter combinations that might trigger immediate sending
campaign_data = {
  subject: 'CCAI Ruby - Immediate Send Test v2',
  title: 'Ruby Immediate Send Test v2',
  message: '<h1>Hello Andreas!</h1><p>This email tests immediate sending with different parameters.</p><p>Time: ' + Time.now.to_s + '</p>',
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
  # Parameters that might trigger immediate sending
  scheduled: false,
  scheduledTimestamp: nil,
  scheduledTimezone: nil,
  sendNow: true,
  immediate: true,
  autoSend: true,
  status: 'ACTIVE'
}

begin
  response = client.email.send_campaign(campaign_data)
  
  puts "✅ Campaign created: #{response['id']}"
  puts "Status: #{response['status']}"
  puts "Total Pending: #{response['totalPending']}"
  puts "Total Sent: #{response['totalSent']}"
  puts "Created: #{response['createdAt']}"
  
  if response['status'] == 'PENDING'
    puts "\n⚠️  Campaign is still PENDING"
    puts "This might be normal - the system may process it shortly"
    puts "Check the CCAI dashboard for campaign ID: #{response['id']}"
  end
  
rescue => e
  puts "❌ Failed: #{e.message}"
end