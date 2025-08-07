#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('lib', __dir__))
require 'ccai'
require 'faraday'
require 'json'

# Load environment variables
begin
  require 'dotenv'
  Dotenv.load
rescue LoadError
end

# Test with query parameter ?send=true
puts "Testing email send with ?send=true parameter..."

connection = Faraday.new do |conn|
  conn.headers['Authorization'] = "Bearer eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJhbmRyZWFzQGFsbGNvZGUuY29tIiwiaXNzIjoiY2xvdWRjb250YWN0IiwibmJmIjoxNzUyMDg5MDk2LCJpYXQiOjE3NTIwODkwOTYsInJvbGUiOiJVU0VSIiwiY2xpZW50SWQiOjEyMzEsImlkIjoxMjIzLCJ0eXBlIjoiQVBJX0tFWSIsImtleV9yYW5kb21faWQiOiIzNTAxZjVmNC0zOWYyLTRjYzctYTk2Yi04ZDkyZjVlMjM5ZGUifQ.XjtDPpyYUJNJjLrpM1pdQ4Sqk90eaagqzPX2v1gwHDP1wOV4fTbB44UGDRXtWyGvN-Fz7o84_Ab-VlAjNCyEmXcDzmzscnwFSbqiZrWLAM_W3Mutd36vArl9QSG_osuYdf9T2wmAduUZu2bcnvKHdBbEaBUalJSSUoHwHsMBX3w"
  conn.headers['Content-Type'] = 'application/json'
  conn.headers['Accept'] = '*/*'
  conn.headers['AccountId'] = '1223'
  conn.headers['ClientId'] = '1231'
  conn.headers['Origin'] = 'https://test-cloudcontactai.allcode.com'
end

campaign_data = {
  subject: 'CCAI Ruby - Send Now Test',
  title: 'Ruby Send Now Test',
  message: '<h1>Hello Andreas!</h1><p>Testing immediate send with query parameter.</p><p>Time: ' + Time.now.to_s + '</p>',
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
  senders: []
}

begin
  response = connection.post(
    'https://email-campaigns-test-cloudcontactai.allcode.com/api/v1/campaigns?send=true',
    campaign_data.to_json
  )
  
  if response.success?
    result = JSON.parse(response.body)
    puts "✅ Campaign created with send=true: #{result['id']}"
    puts "Status: #{result['status']}"
    puts "Total Sent: #{result['totalSent']}"
    puts "Total Pending: #{result['totalPending']}"
    
    if result['totalSent'] > 0
      puts "🎉 EMAIL ACTUALLY SENT!"
    else
      puts "⚠️  Still pending, but trying query parameter worked"
    end
  else
    puts "❌ Failed: #{response.status} - #{response.body}"
  end
rescue => e
  puts "❌ Error: #{e.message}"
end