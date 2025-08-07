#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('lib', __dir__))
require 'ccai'

# Load environment variables
begin
  require 'dotenv'
  Dotenv.load
rescue LoadError
  # dotenv not available, use system env vars
end

# Initialize the client with hardcoded values for now
client = CCAI.new(
  client_id: '1231',
  api_key: 'eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJhbmRyZWFzQGFsbGNvZGUuY29tIiwiaXNzIjoiY2xvdWRjb250YWN0IiwibmJmIjoxNzUyMDg5MDk2LCJpYXQiOjE3NTIwODkwOTYsInJvbGUiOiJVU0VSIiwiY2xpZW50SWQiOjEyMzEsImlkIjoxMjIzLCJ0eXBlIjoiQVBJX0tFWSIsImtleV9yYW5kb21faWQiOiIzNTAxZjVmNC0zOWYyLTRjYzctYTk2Yi04ZDkyZjVlMjM5ZGUifQ.XjtDPpyYUJNJjLrpM1pdQ4Sqk90eaagqzPX2v1gwHDP1wOV4fTbB44UGDRXtWyGvN-Fz7o84_Ab-VlAjNCyEmXcDzmzscnwFSbqiZrWLAM_W3Mutd36vArl9QSG_osuYdf9T2wmAduUZu2bcnvKHdBbEaBUalJSSUoHwHsMBX3w'
)

puts "Sending real email to andreas@allcode.com..."

begin
  response = client.email.send_single(
    'Andreas',
    'AllCode',
    'andreas@allcode.com',
    'CCAI Ruby Client - Real Email Test',
    '<h1>Hello Andreas!</h1><p>This is a REAL email sent from the Ruby CCAI client.</p><p>If you receive this, the email functionality is working correctly!</p><p>Campaign ID will be in the response.</p>',
    'noreply@allcode.com',
    'support@allcode.com',
    'CCAI Ruby Client',
    'Ruby Real Email Test'
  )
  
  puts "✅ Email sent successfully!"
  puts "Campaign ID: #{response['id']}"
  puts "Status: #{response['status']}"
  puts "Created: #{response['createdAt']}"
  puts ""
  puts "Check your email at andreas@allcode.com"
  puts "Also check the CCAI dashboard for campaign ID: #{response['id']}"
  
rescue => e
  puts "❌ Failed to send email: #{e.message}"
end