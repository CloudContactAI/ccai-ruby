# CCAI Ruby Client

A Ruby client for interacting with the Cloud Contact AI API that allows you to easily send SMS, MMS messages, and email campaigns, plus manage webhooks.

## Requirements

- Ruby 2.6 or higher

## Installation

```bash
gem install ccai
```

Or add to your Gemfile:

```ruby
gem 'ccai'
```

## Usage

### SMS

```ruby
require 'ccai'

# Initialize the client
client = CCAI.new(
  client_id: 'YOUR-CLIENT-ID',
  api_key: 'YOUR-API-KEY'
)

# Send a single SMS
response = client.sms.send_single(
  'John',
  'Doe',
  '+15551234567',
  'Hello ${firstName}, this is a test message!',
  'Test Campaign'
)

puts "Message sent with ID: #{response.id}"

# Send to multiple recipients
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

campaign_response = client.sms.send(
  accounts,
  'Hello ${firstName} ${lastName}, this is a test message!',
  'Bulk Test Campaign'
)

puts "Campaign sent with ID: #{campaign_response.campaign_id}"
```

### Email

```ruby
require 'ccai'

# Initialize the client
client = CCAI.new(
  client_id: 'YOUR-CLIENT-ID',
  api_key: 'YOUR-API-KEY'
)

# Send a single email
response = client.email.send_single(
  'John',
  'Doe',
  'john@example.com',
  'Welcome to Our Service',
  '<p>Hello John,</p><p>Thank you for signing up!</p>',
  'noreply@yourcompany.com',
  'support@yourcompany.com',
  'Your Company',
  'Welcome Email'
)

puts "Email sent with ID: #{response['id']}"

# Send email campaign to multiple recipients
campaign = {
  subject: 'Monthly Newsletter',
  title: 'July 2025 Newsletter',
  message: '<h1>Hello ${firstName},</h1><p>Here are our updates...</p>',
  senderEmail: 'newsletter@yourcompany.com',
  replyEmail: 'support@yourcompany.com',
  senderName: 'Your Company',
  accounts: [
    { firstName: 'John', lastName: 'Doe', email: 'john@example.com', phone: '' },
    { firstName: 'Jane', lastName: 'Smith', email: 'jane@example.com', phone: '' }
  ],
  campaignType: 'EMAIL',
  addToList: 'noList',
  contactInput: 'accounts',
  fromType: 'single',
  senders: []
}

response = client.email.send_campaign(campaign)
puts "Campaign sent with ID: #{response['campaignId']}"
```

### Webhooks

```ruby
require 'ccai'

# Initialize the client
client = CCAI.new(
  client_id: 'YOUR-CLIENT-ID',
  api_key: 'YOUR-API-KEY'
)

# Register a webhook
config = {
  url: 'https://your-app.com/webhooks/ccai',
  events: [CCAI::Webhook::EventType::MESSAGE_SENT, CCAI::Webhook::EventType::MESSAGE_RECEIVED],
  secret: 'your-webhook-secret'
}

webhook = client.webhook.register(config)
puts "Webhook registered with ID: #{webhook['id']}"

# List all webhooks
webhooks = client.webhook.list
puts "Registered webhooks: #{webhooks.length}"

# Update a webhook
client.webhook.update(webhook['id'], { url: 'https://your-app.com/new-webhook' })

# Delete a webhook
client.webhook.delete(webhook['id'])

# Verify webhook signature (in your webhook handler)
signature = request.headers['X-CCAI-Signature']
body = request.raw_body
secret = 'your-webhook-secret'

if client.webhook.verify_signature(signature, body, secret)
  # Process the webhook
else
  # Invalid signature
end
```

### MMS

```ruby
require 'ccai'

# Initialize the client
client = CCAI.new(
  client_id: 'YOUR-CLIENT-ID',
  api_key: 'YOUR-API-KEY'
)

# Define progress tracking
options = CCAI::SMS::Options.new(
  timeout: 60,
  on_progress: ->(status) {
    puts "Progress: #{status}"
  }
)

# Complete MMS workflow (get URL, upload image, send MMS)
image_path = 'path/to/your/image.jpg'
content_type = 'image/jpeg'

# Define recipient
account = CCAI::SMS::Account.new(
  first_name: 'John',
  last_name: 'Doe',
  phone: '+15551234567'  # Use E.164 format
)

# Send MMS with image in one step
response = client.mms.send_with_image(
  image_path,
  content_type,
  [account],
  'Hello ${firstName}, check out this image!',
  'MMS Campaign Example',
  options
)

puts "MMS sent! Campaign ID: #{response.campaign_id}"
```

### Step-by-Step MMS Workflow

```ruby
# Step 1: Get a signed URL for uploading
upload_response = client.mms.get_signed_upload_url(
  'image.jpg',
  'image/jpeg'
)

signed_url = upload_response.signed_s3_url
file_key = upload_response.file_key

# Step 2: Upload the image to the signed URL
upload_success = client.mms.upload_image_to_signed_url(
  signed_url,
  'path/to/your/image.jpg',
  'image/jpeg'
)

if upload_success
  # Step 3: Send the MMS with the uploaded image
  response = client.mms.send(
    file_key,
    accounts,
    'Hello ${firstName}, check out this image!',
    'MMS Campaign Example'
  )
  
  puts "MMS sent! Campaign ID: #{response.campaign_id}"
end
```

### With Progress Tracking

```ruby
# Create options with progress tracking
options = CCAI::SMS::Options.new(
  timeout: 60,
  retries: 3,
  on_progress: ->(status) {
    puts "#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} - #{status}"
  }
)

# Send SMS with progress tracking
response = client.sms.send(
  accounts,
  message,
  title,
  options
)
```

## Command-line Tool

The gem includes a command-line tool for sending SMS and MMS messages:

```bash
# Send an SMS
ccai --client-id YOUR-CLIENT-ID --api-key YOUR-API-KEY \
     --first-name John --last-name Doe --phone +15551234567 \
     --message "Hello ${firstName}, this is a test message!" \
     --title "CLI Test"

# Send an MMS
ccai --type mms --client-id YOUR-CLIENT-ID --api-key YOUR-API-KEY \
     --first-name John --last-name Doe --phone +15551234567 \
     --message "Hello ${firstName}, check out this image!" \
     --title "CLI Test" \
     --image path/to/your/image.jpg --content-type image/jpeg

# Send an Email
ccai --type email --client-id YOUR-CLIENT-ID --api-key YOUR-API-KEY \
     --first-name John --last-name Doe --email john@example.com \
     --subject "Welcome" --message "<p>Hello ${firstName}!</p>" \
     --sender-email noreply@yourcompany.com --reply-email support@yourcompany.com \
     --sender-name "Your Company" --title "Welcome Email"
```

## Project Structure

- `lib/` - Library code
  - `ccai.rb` - Main entry point
  - `ccai/` - Core library files
    - `version.rb` - Version information
    - `client.rb` - Main CCAI client
    - `sms/` - SMS-related functionality
      - `models.rb` - Data models
      - `sms_service.rb` - SMS service implementation
      - `mms_service.rb` - MMS service implementation
    - `email/` - Email-related functionality
      - `email_service.rb` - Email service implementation
    - `webhook_service.rb` - Webhook service implementation
- `bin/` - Command-line tools
  - `ccai` - Command-line interface
- `examples/` - Example usage
  - `sms_send.rb` - Basic SMS example
  - `mms_send.rb` - MMS examples
  - `email_example.rb` - Email campaign examples
  - `webhook_example.rb` - Webhook management examples
  - `progress_tracking_example.rb` - Progress tracking example
- `test/` - Test files

## Features

- Send SMS messages to single or multiple recipients
- Send MMS messages with images
- Send email campaigns with HTML content
- Upload images to S3 with signed URLs
- Manage webhooks for real-time event notifications
- Variable substitution in messages
- Progress tracking via callbacks
- Comprehensive error handling
- Full test coverage
- Command-line interface for SMS, MMS, and Email

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
