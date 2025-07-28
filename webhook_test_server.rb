#!/usr/bin/env ruby
# frozen_string_literal: true

require 'webrick'
require 'json'

# Simple webhook test server that processes CCAI webhooks
server = WEBrick::HTTPServer.new(Port: 3000)

server.mount_proc '/webhook' do |req, res|
  if req.request_method == 'POST'
    puts "\n=== Webhook Received ==="
    puts "Headers:"
    req.header.each { |k, v| puts "  #{k}: #{v.join(', ')}" }
    puts "\nBody:"
    puts req.body
    
    # Process webhook payload
    begin
      payload = JSON.parse(req.body)
      puts "\nProcessed Payload:"
      puts "  Type: #{payload['type']}"
      puts "  From: #{payload['from']}"
      puts "  To: #{payload['to']}"
      puts "  Message: #{payload['message']}"
      
      if payload['type'] == 'message.sent'
        puts "  → Outbound message processed"
      elsif payload['type'] == 'message.received'
        puts "  → Inbound message processed"
      end
    rescue JSON::ParserError
      puts "  ⚠️ Invalid JSON payload"
    end
    
    puts "========================\n"
    
    res.status = 200
    res['Content-Type'] = 'application/json'
    res.body = '{"received": true}'
  else
    res.status = 405
    res.body = 'Method not allowed'
  end
end

puts "Webhook test server running on http://localhost:3000/webhook"
puts "Use ngrok to expose: ngrok http 3000"
puts "Press Ctrl+C to stop"

trap('INT') { server.shutdown }
server.start