# frozen_string_literal: true

# Ruby SDK integration tests -- 42 tests
# Covers: SMS (1-6), MMS (7-17), Email (18-22), Webhook (23-29), Contact (30-31),
#         Brands (32-36), Campaigns (37-42)

require 'ccai'
require 'openssl'
require 'base64'
require 'json'
require 'tempfile'

# ── Helpers ───────────────────────────────────────────────────────────────────

passed = 0
failed = 0

def run_test(name)
  yield
  puts "  PASS [#{name}]"
  return true
rescue => e
  puts "  FAIL [#{name}]: #{e.message}"
  return false
end

def must_env(key)
  val = ENV[key]
  if val.nil? || val.empty?
    warn "ERROR: required env var #{key} is not set"
    exit 2
  end
  val
end

def hmac_sha256_base64(secret, message)
  digest = OpenSSL::HMAC.digest('SHA256', secret, message)
  Base64.strict_encode64(digest)
end

# Write a 1x1 PNG to a temp file and return the Tempfile object (keep reference alive)
def write_temp_png
  png_b64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwADhQGAWjR9awAAAABJRU5ErkJggg=='
  buf = Base64.decode64(png_b64)
  tmp = Tempfile.new(['ccai_test', '.png'])
  tmp.binmode
  tmp.write(buf)
  tmp.flush
  tmp  # return the object, not just the path — prevents GC from deleting the file
end

# ── Setup ─────────────────────────────────────────────────────────────────────

client_id   = must_env('CCAI_CLIENT_ID')
api_key     = must_env('CCAI_API_KEY')
phone1      = must_env('CCAI_TEST_PHONE')
phone2      = must_env('CCAI_TEST_PHONE_2')
phone3      = must_env('CCAI_TEST_PHONE_3')
email1      = must_env('CCAI_TEST_EMAIL')
email2      = must_env('CCAI_TEST_EMAIL_2')
email3      = must_env('CCAI_TEST_EMAIL_3')
fn1         = must_env('CCAI_TEST_FIRST_NAME')
ln1         = must_env('CCAI_TEST_LAST_NAME')
fn2         = must_env('CCAI_TEST_FIRST_NAME_2')
ln2         = must_env('CCAI_TEST_LAST_NAME_2')
fn3         = must_env('CCAI_TEST_FIRST_NAME_3')
ln3         = must_env('CCAI_TEST_LAST_NAME_3')
webhook_url = must_env('WEBHOOK_URL')

client = CCAI::Client.new(
  CCAI::Config.new(
    client_id: client_id,
    api_key: api_key,
    use_test_environment: true
  )
)

png_path = write_temp_png

puts '=============================================='
puts '  CCAI Ruby SDK Integration Tests'
puts '=============================================='

# ── SMS Tests (1-6) ───────────────────────────────────────────────────────────
puts "\n--- SMS ---"

# 01 -- SMS.send_single
result = run_test('01 SMS.send_single') do
  client.sms.send_single(fn1, ln1, phone1, 'Hello from Ruby SDK!', 'Ruby Test')
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# 02 -- SMS.send (1 recipient)
result = run_test('02 SMS.send (1 recipient)') do
  accounts = [CCAI::SMS::Account.new(first_name: fn1, last_name: ln1, phone: phone1)]
  client.sms.send(accounts, 'Hello 1 recipient!', 'Ruby Test')
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# 03 -- SMS.send (2 recipients)
result = run_test('03 SMS.send (2 recipients)') do
  accounts = [
    CCAI::SMS::Account.new(first_name: fn1, last_name: ln1, phone: phone1),
    CCAI::SMS::Account.new(first_name: fn2, last_name: ln2, phone: phone2)
  ]
  client.sms.send(accounts, 'Hello 2 recipients!', 'Ruby Test')
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# 04 -- SMS.send (3 recipients)
result = run_test('04 SMS.send (3 recipients)') do
  accounts = [
    CCAI::SMS::Account.new(first_name: fn1, last_name: ln1, phone: phone1),
    CCAI::SMS::Account.new(first_name: fn2, last_name: ln2, phone: phone2),
    CCAI::SMS::Account.new(first_name: fn3, last_name: ln3, phone: phone3)
  ]
  client.sms.send(accounts, 'Hello 3 recipients!', 'Ruby Test')
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# 05 -- SMS.send with data
result = run_test('05 SMS.send with data') do
  accounts = [CCAI::SMS::Account.new(first_name: fn1, last_name: ln1, phone: phone1, data: { 'city' => 'Miami', 'offer' => '20% off' })]
  client.sms.send(accounts, 'Hello from ${city}! Claim your ${offer}.', 'Ruby Test Data')
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# 06 -- SMS.send with custom_data (messageData)
result = run_test('06 SMS.send with custom_data') do
  accounts = [CCAI::SMS::Account.new(first_name: fn1, last_name: ln1, phone: phone1, custom_data: '{"trackingId":"ruby-001"}')]
  client.sms.send(accounts, 'Hello with messageData!', 'Ruby Test MsgData')
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# ── MMS Tests (7-17) ──────────────────────────────────────────────────────────
puts "\n--- MMS ---"

signed_url_resp = nil
mms_dep = false

# 07 -- MMS.get_signed_upload_url
result = run_test('07 MMS.get_signed_upload_url') do
  resp = client.mms.get_signed_upload_url('test_image.png', 'image/png')
  if resp.signed_s3_url.nil? || resp.signed_s3_url.empty?
    mms_dep = true
    raise 'signed_s3_url is empty'
  end
  signed_url_resp = resp
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# 08 -- MMS.upload_image_to_signed_url
result = run_test('08 MMS.upload_image_to_signed_url') do
  raise 'dependency test 07 failed' if mms_dep || signed_url_resp.nil?
  ok = client.mms.upload_image_to_signed_url(signed_url_resp.signed_s3_url, png_path.path, 'image/png')
  raise 'upload returned false' unless ok
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# 09 -- MMS.send_single
result = run_test('09 MMS.send_single') do
  raise 'dependency test 07 failed' if mms_dep || signed_url_resp.nil?
  client.mms.send_single(signed_url_resp.file_key, fn1, ln1, phone1, 'MMS single!', 'Ruby MMS Test')
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# 10 -- MMS.send (1 recipient)
result = run_test('10 MMS.send (1 recipient)') do
  raise 'dependency test 07 failed' if mms_dep || signed_url_resp.nil?
  accounts = [CCAI::SMS::Account.new(first_name: fn1, last_name: ln1, phone: phone1)]
  client.mms.send(signed_url_resp.file_key, accounts, 'MMS 1 recipient!', 'Ruby MMS Test')
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# 11 -- MMS.send (2 recipients)
result = run_test('11 MMS.send (2 recipients)') do
  raise 'dependency test 07 failed' if mms_dep || signed_url_resp.nil?
  accounts = [
    CCAI::SMS::Account.new(first_name: fn1, last_name: ln1, phone: phone1),
    CCAI::SMS::Account.new(first_name: fn2, last_name: ln2, phone: phone2)
  ]
  client.mms.send(signed_url_resp.file_key, accounts, 'MMS 2 recipients!', 'Ruby MMS Test')
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# 12 -- MMS.send (3 recipients)
result = run_test('12 MMS.send (3 recipients)') do
  raise 'dependency test 07 failed' if mms_dep || signed_url_resp.nil?
  accounts = [
    CCAI::SMS::Account.new(first_name: fn1, last_name: ln1, phone: phone1),
    CCAI::SMS::Account.new(first_name: fn2, last_name: ln2, phone: phone2),
    CCAI::SMS::Account.new(first_name: fn3, last_name: ln3, phone: phone3)
  ]
  client.mms.send(signed_url_resp.file_key, accounts, 'MMS 3 recipients!', 'Ruby MMS Test')
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# 13 -- MMS.send with data
result = run_test('13 MMS.send with data') do
  raise 'dependency test 07 failed' if mms_dep || signed_url_resp.nil?
  accounts = [CCAI::SMS::Account.new(first_name: fn1, last_name: ln1, phone: phone1, data: { 'product' => 'Widget' })]
  client.mms.send(signed_url_resp.file_key, accounts, 'Check out ${product}!', 'Ruby MMS Data')
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# 14 -- MMS.send with custom_data
result = run_test('14 MMS.send with custom_data') do
  raise 'dependency test 07 failed' if mms_dep || signed_url_resp.nil?
  accounts = [CCAI::SMS::Account.new(first_name: fn1, last_name: ln1, phone: phone1, custom_data: '{"campaignId":"mms-ruby-001"}')]
  client.mms.send(signed_url_resp.file_key, accounts, 'MMS with messageData!', 'Ruby MMS MsgData')
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# 15 -- MMS.check_file_uploaded
result = run_test('15 MMS.check_file_uploaded') do
  raise 'dependency test 07 failed' if mms_dep || signed_url_resp.nil?
  client.mms.check_file_uploaded(signed_url_resp.file_key)
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# 16 -- MMS.send_with_image (fresh upload)
result = run_test('16 MMS.send_with_image (fresh upload)') do
  raise 'dependency test 07 failed' if mms_dep
  accounts = [CCAI::SMS::Account.new(first_name: fn1, last_name: ln1, phone: phone1)]
  client.mms.send_with_image(png_path.path, 'image/png', accounts, 'MMS with image!', 'Ruby MMS Image', nil, nil, true)
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# 17 -- MMS.send_with_image (cached)
result = run_test('17 MMS.send_with_image (cached)') do
  raise 'dependency test 07 failed' if mms_dep
  accounts = [CCAI::SMS::Account.new(first_name: fn1, last_name: ln1, phone: phone1)]
  client.mms.send_with_image(png_path.path, 'image/png', accounts, 'MMS cached image!', 'Ruby MMS Cache', nil, nil, true)
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# ── Email Tests (18-22) ───────────────────────────────────────────────────────
puts "\n--- Email ---"

SENDER_EMAIL = 'noreply@cloudcontactai.com'
SENDER_NAME  = 'CCAI Test'
REPLY_EMAIL  = 'noreply@cloudcontactai.com'

# 18 -- Email.send_single
result = run_test('18 Email.send_single') do
  client.email.send_single(
    fn1, ln1, email1,
    'Ruby SDK Test Email', '<p>Hello from Ruby SDK!</p>',
    nil, SENDER_EMAIL, REPLY_EMAIL, SENDER_NAME, 'Ruby Email Test'
  )
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# 19 -- Email.send (1 recipient)
result = run_test('19 Email.send (1 recipient)') do
  accounts = [{ firstName: fn1, lastName: ln1, email: email1, phone: '' }]
  client.email.send(accounts, 'Ruby SDK Email 1', '<p>Hello 1!</p>', SENDER_EMAIL, REPLY_EMAIL, SENDER_NAME, 'Ruby Email Test')
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# 20 -- Email.send (2 recipients)
result = run_test('20 Email.send (2 recipients)') do
  accounts = [
    { firstName: fn1, lastName: ln1, email: email1, phone: '' },
    { firstName: fn2, lastName: ln2, email: email2, phone: '' }
  ]
  client.email.send(accounts, 'Ruby SDK Email 2', '<p>Hello 2!</p>', SENDER_EMAIL, REPLY_EMAIL, SENDER_NAME, 'Ruby Email Test')
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# 21 -- Email.send (3 recipients)
result = run_test('21 Email.send (3 recipients)') do
  accounts = [
    { firstName: fn1, lastName: ln1, email: email1, phone: '' },
    { firstName: fn2, lastName: ln2, email: email2, phone: '' },
    { firstName: fn3, lastName: ln3, email: email3, phone: '' }
  ]
  client.email.send(accounts, 'Ruby SDK Email 3', '<p>Hello 3!</p>', SENDER_EMAIL, REPLY_EMAIL, SENDER_NAME, 'Ruby Email Test')
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# 22 -- Email.send_campaign (full campaign hash)
result = run_test('22 Email.send_campaign') do
  campaign = {
    subject: 'Ruby SDK Campaign Test',
    title: 'Ruby Email Campaign',
    message: '<p>Campaign email from Ruby SDK!</p>',
    senderEmail: SENDER_EMAIL,
    replyEmail: REPLY_EMAIL,
    senderName: SENDER_NAME,
    accounts: [
      { firstName: fn1, lastName: ln1, email: email1, phone: '' },
      { firstName: fn2, lastName: ln2, email: email2, phone: '' }
    ],
    campaignType: 'EMAIL',
    addToList: 'noList',
    contactInput: 'accounts',
    fromType: 'single',
    senders: []
  }
  client.email.send_campaign(campaign)
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# ── Webhook Tests (23-29) ─────────────────────────────────────────────────────
puts "\n--- Webhook ---"

WEBHOOK_SECRET = 'test-webhook-secret-ruby'
registered_webhook_id = nil

# 23 -- Webhook.register
result = run_test('23 Webhook.register') do
  resp = client.webhook.register(url: webhook_url, secret: WEBHOOK_SECRET)
  id = resp['id'] || resp[:id]
  raise 'webhook ID is empty after register' if id.nil? || id.to_s.empty? || id.to_i == 0
  registered_webhook_id = id.to_i
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# 24 -- Webhook.list
result = run_test('24 Webhook.list') do
  hooks = client.webhook.list
  raise 'expected at least one webhook, got 0' unless hooks.is_a?(Array) && !hooks.empty?
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# 25 -- Webhook.update
result = run_test('25 Webhook.update') do
  raise 'no webhook ID from test 23' if registered_webhook_id.nil?
  client.webhook.update(registered_webhook_id, url: "#{webhook_url}?updated=1", secret: 'updated-secret-ruby')
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# 26 -- Webhook.verify_signature (valid)
result = run_test('26 Webhook.verify_signature (valid)') do
  event_hash = 'abc123eventHash'
  sig = hmac_sha256_base64(WEBHOOK_SECRET, "#{client_id}:#{event_hash}")
  ok = client.webhook.verify_signature(sig, client_id, event_hash, WEBHOOK_SECRET)
  raise 'expected valid signature to return true' unless ok
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# 27 -- Webhook.verify_signature (invalid)
result = run_test('27 Webhook.verify_signature (invalid)') do
  ok = client.webhook.verify_signature('invalidsig==', client_id, 'somehash', WEBHOOK_SECRET)
  raise 'expected invalid signature to return false' if ok
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# 28 -- Webhook.parse_event
result = run_test('28 Webhook.parse_event') do
  payload = '{"eventType":"message.sent","data":{"To":"+15005550001","Message":"test","MessageStatus":"DELIVERED"}}'
  evt = client.webhook.parse_event(payload)
  raise 'eventType is missing after parse_event' unless evt['eventType']
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# 29 -- Webhook.delete
result = run_test('29 Webhook.delete') do
  raise 'no webhook ID from test 23' if registered_webhook_id.nil?
  client.webhook.delete(registered_webhook_id)
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# ── Contact Tests (30-31) ─────────────────────────────────────────────────────
puts "\n--- Contact ---"

# 30 -- Contact.set_do_not_text(true)
result = run_test('30 Contact.set_do_not_text(true)') do
  client.contact.set_do_not_text(true, phone: phone1)
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# 31 -- Contact.set_do_not_text(false)
result = run_test('31 Contact.set_do_not_text(false)') do
  client.contact.set_do_not_text(false, phone: phone1)
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# ── Brands Tests (32-36) ──────────────────────────────────────────────────────
puts "\n--- Brands ---"

created_brand_id = nil

BRAND_PAYLOAD = {
  legalCompanyName: 'Ruby SDK Test Brand LLC',
  dba:              'Ruby SDK Test Brand',
  entityType:       'PRIVATE_PROFIT',
  taxId:            '123456789',
  taxIdCountry:     'US',
  country:          'US',
  verticalType:     'TECHNOLOGY',
  websiteUrl:       'https://rubysdk.example.com',
  street:           '123 Test St',
  city:             'Miami',
  state:            'FL',
  postalCode:       '33101',
  contactFirstName: 'Test',
  contactLastName:  'User',
  contactEmail:     email1,
  contactPhone:     phone1,
}.freeze

# 32 -- Brand.create
result = run_test('32 Brand.create') do
  resp = client.brand.create(BRAND_PAYLOAD)
  id = resp['id'] || resp[:id]
  raise 'brand ID is empty after create' if id.nil? || id.to_s.empty?
  created_brand_id = id.to_s
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# 33 -- Brand.get
result = run_test('33 Brand.get') do
  raise 'no brand ID from test 32' if created_brand_id.nil?
  resp = client.brand.get(created_brand_id)
  raise 'expected brand response to be a Hash' unless resp.is_a?(Hash)
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# 34 -- Brand.list
result = run_test('34 Brand.list') do
  resp = client.brand.list
  raise 'expected list response to be a Hash or Array' unless resp.is_a?(Hash) || resp.is_a?(Array)
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# 35 -- Brand.update
result = run_test('35 Brand.update') do
  raise 'no brand ID from test 32' if created_brand_id.nil?
  client.brand.update(created_brand_id, { city: 'Fort Lauderdale' })
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# 36 -- Brand.delete
result = run_test('36 Brand.delete') do
  raise 'no brand ID from test 32' if created_brand_id.nil?
  client.brand.delete(created_brand_id)
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# ── Campaigns Tests (37-42) ───────────────────────────────────────────────────
puts "\n--- Campaigns ---"

campaign_brand_id = nil
created_campaign_id = nil

# 37 -- Campaign setup: create a brand to use
result = run_test('37 Campaign setup — Brand.create') do
  resp = client.brand.create(BRAND_PAYLOAD)
  id = resp['id'] || resp[:id]
  raise 'brand ID is empty for campaign setup' if id.nil? || id.to_s.empty?
  campaign_brand_id = id.to_s
end
passed += result ? 1 : 0; failed += result ? 0 : 1

CAMPAIGN_PAYLOAD_TEMPLATE = {
  useCase:          'MARKETING',
  description:      'Ruby SDK test campaign for integration testing',
  messageFlow:      'Users opt-in via our website form.',
  hasEmbeddedLinks: false,
  hasEmbeddedPhone: false,
  isAgeGated:       false,
  isDirectLending:  false,
  optInKeywords:    %w[START YES],
  optInMessage:     'You are now subscribed. Reply STOP to unsubscribe.',
  optInProofUrl:    'https://rubysdk.example.com/optin',
  helpKeywords:     %w[HELP INFO],
  helpMessage:      'For help, contact support@example.com. Reply HELP for assistance.',
  optOutKeywords:   %w[STOP CANCEL],
  optOutMessage:    'You have been unsubscribed. Reply STOP to opt out.',
  sampleMessages:   [
    'Hello! Reply STOP to opt out.',
    'Hi there! Reply HELP for assistance.'
  ],
}.freeze

# 38 -- Campaign.create
result = run_test('38 Campaign.create') do
  raise 'no brand ID from test 37' if campaign_brand_id.nil?
  payload = CAMPAIGN_PAYLOAD_TEMPLATE.merge(brandId: campaign_brand_id)
  resp = client.campaign.create(payload)
  id = resp['id'] || resp[:id]
  raise 'campaign ID is empty after create' if id.nil? || id.to_s.empty?
  created_campaign_id = id.to_s
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# 39 -- Campaign.get
result = run_test('39 Campaign.get') do
  raise 'no campaign ID from test 38' if created_campaign_id.nil?
  resp = client.campaign.get(created_campaign_id)
  raise 'expected campaign response to be a Hash' unless resp.is_a?(Hash)
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# 40 -- Campaign.list
result = run_test('40 Campaign.list') do
  resp = client.campaign.list
  raise 'expected list response to be a Hash or Array' unless resp.is_a?(Hash) || resp.is_a?(Array)
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# 41 -- Campaign.update
result = run_test('41 Campaign.update') do
  raise 'no campaign ID from test 38' if created_campaign_id.nil?
  client.campaign.update(created_campaign_id, { description: 'Updated Ruby SDK campaign' })
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# 42 -- Campaign.delete
result = run_test('42 Campaign.delete') do
  raise 'no campaign ID from test 38' if created_campaign_id.nil?
  client.campaign.delete(created_campaign_id)
end
passed += result ? 1 : 0; failed += result ? 0 : 1

# cleanup campaign brand
client.brand.delete(campaign_brand_id) if campaign_brand_id

# ── Cleanup & Results ─────────────────────────────────────────────────────────
png_path.close!  # cleanup Tempfile

puts "\n=============================================="
puts "  RESULTS: #{passed} passed, #{failed} failed"
puts "=============================================="

summary = JSON.generate({ sdk: 'ruby', passed: passed, failed: failed, total: passed + failed })
puts "\nSUMMARY_JSON: #{summary}"

exit(failed > 0 ? 1 : 0)
