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

# Example 1: Send a single email
def send_single_email(client)
  puts "=== Sending Single Email ==="
  
  begin
    response = client.email.send_single(
      'Andreas',
      'Doe',
      'andreas@allcode.com',
      'Welcome to Our Service',
      '<p>Hello Andreas,</p><p>Thank you for signing up for our service!</p><p>Best regards,<br>AllCode Team</p>',
      'noreply@allcode.com',
      'support@allcode.com',
      'AllCode',
      'Welcome Email'
    )
    
    puts "Email sent successfully: #{response}"
  rescue => e
    puts "Error sending email: #{e.message}"
  end
end

# Example 2: Send an email campaign to multiple recipients
def send_email_campaign(client)
  puts "\n=== Sending Email Campaign ==="
  
  begin
    campaign = {
      subject: 'Monthly Newsletter',
      title: 'July 2025 Newsletter',
      message: <<~HTML,
        <h1>Monthly Newsletter - July 2025</h1>
        <p>Hello ${firstName},</p>
        <p>Here are our updates for this month:</p>
        <ul>
          <li>New feature: Email campaigns</li>
          <li>Improved performance</li>
          <li>Bug fixes</li>
        </ul>
        <p>Thank you for being a valued customer!</p>
        <p>Best regards,<br>The Team</p>
      HTML
      senderEmail: 'newsletter@yourcompany.com',
      replyEmail: 'support@yourcompany.com',
      senderName: 'Your Company Newsletter',
      accounts: [
        {
          firstName: 'John',
          lastName: 'Doe',
          email: 'john@example.com',
          phone: ''
        },
        {
          firstName: 'Jane',
          lastName: 'Smith',
          email: 'jane@example.com',
          phone: ''
        }
      ],
      campaignType: 'EMAIL',
      addToList: 'noList',
      contactInput: 'accounts',
      fromType: 'single',
      senders: []
    }
    
    options = CCAI::SMS::Options.new(
      on_progress: ->(status) { puts "Status: #{status}" }
    )
    
    response = client.email.send_campaign(campaign, options)
    puts "Email campaign sent successfully: #{response}"
  rescue => e
    puts "Error sending email campaign: #{e.message}"
  end
end

# Example 3: Send HTML template email
def send_html_template_email(client)
  puts "\n=== Sending HTML Template Email ==="
  
  begin
    html_template = <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; }
          .header { background-color: #4CAF50; color: white; padding: 20px; text-align: center; }
          .content { padding: 20px; }
          .footer { background-color: #f1f1f1; padding: 10px; text-align: center; }
        </style>
      </head>
      <body>
        <div class="header">
          <h1>Welcome, ${firstName}!</h1>
        </div>
        <div class="content">
          <p>Thank you for joining our platform.</p>
          <p>Here are some resources to get you started:</p>
          <ul>
            <li><a href="https://example.com/docs">Documentation</a></li>
            <li><a href="https://example.com/tutorials">Tutorials</a></li>
            <li><a href="https://example.com/support">Support</a></li>
          </ul>
        </div>
        <div class="footer">
          <p>&copy; 2025 Your Company. All rights reserved.</p>
        </div>
      </body>
      </html>
    HTML
    
    response = client.email.send_single(
      'John',
      'Doe',
      'john@example.com',
      'Welcome to Our Platform',
      html_template,
      'welcome@yourcompany.com',
      'support@yourcompany.com',
      'Your Company',
      'Welcome HTML Template Email'
    )
    
    puts "HTML template email sent successfully: #{response}"
  rescue => e
    puts "Error sending HTML template email: #{e.message}"
  end
end

# Run the examples
send_single_email(client)
send_email_campaign(client)
send_html_template_email(client)