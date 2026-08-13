# CCAI Ruby Client

A Ruby client for interacting with the Cloud Contact AI API that allows you to easily send SMS, MMS messages, and email campaigns, manage webhooks, register brands for TCR verification, and register campaigns for TCR carrier vetting.

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

### SMS — Template-Controlled Accounts

If an account has been configured to enforce template-only messaging, all campaigns must reference a pre-approved template ID. Sending a free-text message to such an account will result in a `422` error.

```ruby
# Send to multiple recipients using a template
response = client.sms.send_with_template(
  accounts,
  12345,          # template_id — the ID of the approved template
  'My Campaign'
)

# Send to a single recipient using a template
response = client.sms.send_single_with_template(
  'John',
  'Doe',
  '+15551234567',
  12345,          # template_id
  'My Campaign'
)

puts "Campaign sent with ID: #{response.campaign_id}"
```

The message body is resolved server-side from the template. Variable substitution (e.g. `${firstName}`) is applied automatically using the recipient's account data.

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
  nil,                                # text_content
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

### Contact

Manage opt-out preferences for contacts.

```ruby
require 'ccai'

# Initialize the client
client = CCAI.new(
  client_id: 'YOUR-CLIENT-ID',
  api_key: 'YOUR-API-KEY'
)

# Opt a contact out of text messages (by phone)
result = client.contact.set_do_not_text(true, phone: '+15551234567')
puts "Opted out: #{result}"

# Opt a contact back in
client.contact.set_do_not_text(false, phone: '+15551234567')

# Opt out by contact_id
client.contact.set_do_not_text(true, contact_id: 'contact-abc-123')
```

### Contact Validator

Validate email addresses and phone numbers.

> Bulk endpoints accept up to 50 contacts per request and are processed server-side in chunks.

```ruby
require 'ccai'

# Initialize the client
client = CCAI.new(
  client_id: 'YOUR-CLIENT-ID',
  api_key: 'YOUR-API-KEY'
)

# Validate a single email
email_result = client.contact_validator.validate_email('user@example.com')
puts "Status: #{email_result['status']}" # "valid" | "invalid" | "risky"

# Validate multiple emails (up to 50, processed server-side in chunks)
bulk_emails = client.contact_validator.validate_emails(['user@example.com', 'bad@invalid.xyz'])
puts "Total: #{bulk_emails['summary']['total']}" # 2
puts "Valid: #{bulk_emails['summary']['valid']}"  # 1

# Validate a single phone number
phone_result = client.contact_validator.validate_phone('+15551234567', country_code: 'US')
puts "Status: #{phone_result['status']}" # "valid" | "invalid" | "landline"

# Validate multiple phone numbers (up to 50, processed server-side in chunks)
bulk_phones = client.contact_validator.validate_phones([
  { phone: '+15551234567' },
  { phone: '+15559876543', countryCode: 'US' }
])
puts "Landline: #{bulk_phones['summary']['landline']}" # 1
```

### Brand Registration

Register and manage brands for TCR verification.

```ruby
require 'ccai'

# Initialize the client
client = CCAI.new(
  client_id: 'YOUR-CLIENT-ID',
  api_key: 'YOUR-API-KEY'
)

# Create a brand
brand = client.brand.create(
  legalCompanyName: 'Collect.org Inc.',
  dba: 'Collect',
  entityType: 'NON_PROFIT',
  taxId: '123456789',
  taxIdCountry: 'US',
  country: 'US',
  verticalType: 'NON_PROFIT',
  websiteUrl: 'https://www.collect.org',
  street: '123 Main Street',
  city: 'San Francisco',
  state: 'CA',
  postalCode: '94105',
  contactFirstName: 'Jane',
  contactLastName: 'Doe',
  contactEmail: 'jane@collect.org',
  contactPhone: '+14155551234'
)
puts "Brand created with ID: #{brand['id']}"

# Get a brand by ID
fetched = client.brand.get(brand['id'])
puts "Website match score: #{fetched['websiteMatchScore'] || 'pending'}"

# List all brands
brands = client.brand.list
puts "Found #{brands.length} brand(s)"

# Update a brand (partial update)
client.brand.update(brand['id'],
  street: '456 Oak Avenue',
  city: 'Los Angeles'
)

# Delete a brand
client.brand.delete(brand['id'])
```

**Entity Types:** `PRIVATE_PROFIT`, `PUBLIC_PROFIT`, `NON_PROFIT`, `GOVERNMENT`, `SOLE_PROPRIETOR`

> Note: `PUBLIC_PROFIT` entities require `stockSymbol` and `stockExchange` fields.

**Vertical Types:** `AUTOMOTIVE`, `AGRICULTURE`, `BANKING`, `COMMUNICATION`, `CONSTRUCTION`, `EDUCATION`, `ENERGY`, `ENTERTAINMENT`, `GOVERNMENT`, `HEALTHCARE`, `HOSPITALITY`, `INSURANCE`, `LEGAL`, `MANUFACTURING`, `NON_PROFIT`, `PROFESSIONAL`, `REAL_ESTATE`, `RETAIL`, `TECHNOLOGY`, `TRANSPORTATION`

### Campaign Registration

Register and manage campaigns for TCR carrier vetting.

```ruby
require 'ccai'

# Initialize the client
client = CCAI.new(
  client_id: 'YOUR-CLIENT-ID',
  api_key: 'YOUR-API-KEY'
)

# Create a campaign
campaign = client.campaign.create(
  brandId: 1,
  useCase: 'MIXED',
  subUseCases: ['CUSTOMER_CARE', 'TWO_FACTOR_AUTHENTICATION', 'ACCOUNT_NOTIFICATION'],
  description: 'Security codes and support messaging.',
  messageFlow: 'Users opt-in via signup form at https://example.com/signup',
  hasEmbeddedLinks: true,
  hasEmbeddedPhone: false,
  isAgeGated: false,
  isDirectLending: false,
  optInKeywords: ['START'],
  optInMessage: 'Welcome! Reply STOP to cancel.',
  optInProofUrl: 'https://example.com/opt-in-proof.png',
  helpKeywords: ['HELP'],
  helpMessage: 'For HELP email support@example.com.',
  optOutKeywords: ['STOP'],
  optOutMessage: 'STOP received. You are unsubscribed.',
  sampleMessages: [
    'Your code is 554321. Reply STOP to cancel.',
    'Your ticket has been updated. Reply HELP for info.'
  ],
  termsLink: 'https://example.com/terms',
  privacyLink: 'https://example.com/privacy'
)
puts "Campaign created with ID: #{campaign['id']}"

# Get a campaign by ID
fetched = client.campaign.get(campaign['id'])
puts "Campaign use case: #{fetched['useCase']}"

# List all campaigns
campaigns = client.campaign.list
puts "Found #{campaigns.length} campaign(s)"

# Update a campaign (partial update)
client.campaign.update(campaign['id'],
  description: 'Updated description.'
)

# Delete a campaign
client.campaign.delete(campaign['id'])
```

**Use Cases:** `TWO_FACTOR_AUTHENTICATION`, `ACCOUNT_NOTIFICATION`, `CUSTOMER_CARE`, `DELIVERY_NOTIFICATION`, `FRAUD_ALERT`, `HIGHER_EDUCATION`, `LOW_VOLUME_MIXED`, `MARKETING`, `MIXED`, `POLLING_VOTING`, `PUBLIC_SERVICE_ANNOUNCEMENT`, `SECURITY_ALERT`

> Note: `MIXED` and `LOW_VOLUME_MIXED` campaigns require 2–3 `subUseCases`.

**Sub-Use Cases:** `TWO_FACTOR_AUTHENTICATION`, `ACCOUNT_NOTIFICATION`, `CUSTOMER_CARE`, `DELIVERY_NOTIFICATION`, `FRAUD_ALERT`, `MARKETING`, `POLLING_VOTING`

### Webhooks

```ruby
require 'ccai'

# Initialize the client
client = CCAI.new(
  client_id: 'YOUR-CLIENT-ID',
  api_key: 'YOUR-API-KEY'
)

# Example 1: Register a webhook with auto-generated secret
# If secret is not provided, the server will auto-generate one
config = {
  url: 'https://your-app.com/webhooks/ccai'
  # secret not provided - server will auto-generate and return it
}

webhook = client.webhook.register(config)
puts "Webhook registered with ID: #{webhook['id']}"
puts "Auto-generated Secret: #{webhook['secretKey']}"

# Example 2: Register a webhook with a custom secret
config_custom = {
  url: 'https://your-app.com/webhooks/ccai-v2',
  secret: 'my-custom-secret-key'
}

webhook_custom = client.webhook.register(config_custom)
puts "Webhook with custom secret registered: #{webhook_custom['id']}"

# List all webhooks
webhooks = client.webhook.list
puts "Registered webhooks: #{webhooks.length}"

# Update a webhook
updated = client.webhook.update(webhook['id'], { url: 'https://your-app.com/new-webhook' })
puts "Webhook updated: #{updated['url']}"

# Delete a webhook
result = client.webhook.delete(webhook['id'])
puts "Webhook deleted" if result['success']

# Verify webhook signature (in your webhook handler)
signature = request.headers['X-CCAI-Signature']
body = request.raw_body
secret = 'your-webhook-secret'  # Use the secret returned during registration

# Parse the webhook payload to get client_id and event_hash
payload = JSON.parse(body)
client_id = ENV['CCAI_CLIENT_ID']
event_hash = payload['eventHash']

if client.webhook.verify_signature(signature, client_id, event_hash, secret)
  # Process the webhook
  event = client.webhook.parse_event(body)
  puts "Webhook event type: #{event['eventType']}"
  puts "Webhook data: #{event['data']}"
else
  # Invalid signature
  puts "Invalid signature"
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
  nil,      # sender_phone
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
  on_progress: ->(status) {
    puts "#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} - #{status}"
  }
)

# Send SMS with progress tracking
response = client.sms.send(
  accounts,
  message,
  title,
  nil,      # sender_phone
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
    - `sms/` - SMS and MMS functionality
      - `models.rb` - Data models
      - `sms_service.rb` - SMS service implementation
      - `mms_service.rb` - MMS service implementation
    - `email/` - Email-related functionality
      - `email_service.rb` - Email service implementation
    - `webhook/` - Webhook management
      - `webhook_service.rb` - Webhook service implementation
    - `contact/` - Contact opt-out preferences
      - `contact_service.rb` - Contact service implementation
    - `contact_validator/` - Email/phone validation
      - `contact_validator_service.rb` - Contact validator service implementation
    - `brand/` - Brand registration (10DLC)
      - `brand_service.rb` - Brand service implementation
    - `campaign/` - Campaign registration (10DLC)
      - `campaign_service.rb` - Campaign service implementation
- `bin/` - Command-line tools
  - `ccai` - Command-line interface
- `examples/` - Example usage
  - `sms_send.rb` - Basic SMS example
  - `mms_send.rb` / `mms_example.rb` - MMS examples
  - `email_example.rb` - Email campaign examples
  - `webhook_example.rb`, `webhook_handler_rails.rb`, `webhook_handler_sinatra.rb` - Webhook management examples
  - `progress_tracking_example.rb` - Progress tracking example
- `test/` - Test files

## Features

- Send SMS messages to single or multiple recipients
- Send MMS messages with images (automatic S3 upload)
- Send email campaigns with HTML content
- Manage contact opt-out preferences (set_do_not_text)
- Validate email addresses (valid/invalid/risky) and phone numbers (valid/invalid/landline)
- Brand registration and management for TCR verification
- Campaign registration and management for TCR carrier vetting
- Manage webhooks: register, list, update, delete
- Webhook signature verification (HMAC-SHA256 with Base64 encoding)
- Template variable substitution (`${firstName}`, `${lastName}`)
- Progress tracking via callbacks
- Comprehensive error handling
- Full test coverage
- Command-line interface for SMS, MMS, and Email

## Removed Functionality

The following methods have been removed as they do not exist in the backend API:
- `SMSService#get_campaign_status()` - Use backend API directly for campaign status
- `EmailService#get_campaign_status()` - Use backend API directly for campaign status

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
