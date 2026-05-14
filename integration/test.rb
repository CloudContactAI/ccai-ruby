# frozen_string_literal: true

# Ruby SDK integration tests -- 52 tests
# Covers: SMS (1-6), MMS (7-17), Email (18-22), Webhook (23-29), Contact (30-31),
#         Brands (32-36), Campaigns (37-42), ContactValidator (43-46), Negative cases (47-52)
#
# Test results use three states:
#   PASS -- the test ran and all assertions held
#   FAIL -- the test ran and an assertion (or the API call) failed
#   SKIP -- a prerequisite test failed, so this test could not run
#
# Resources created during the run (webhooks, brands, campaigns) are tracked and
# deleted in a final cleanup block even if tests fail midway.

require 'ccai'
require 'openssl'
require 'base64'
require 'json'
require 'tempfile'

# ── Helpers ───────────────────────────────────────────────────────────────────

# Raised when a test cannot run because a prerequisite test failed.
class SkipTest < StandardError; end

$passed = 0
$failed = 0
$skipped = 0

def run_test(name)
  yield
  puts "  PASS [#{name}]"
  $passed += 1
rescue SkipTest => e
  puts "  SKIP [#{name}]: #{e.message}"
  $skipped += 1
rescue StandardError => e
  puts "  FAIL [#{name}]: #{e.message}"
  $failed += 1
end

# Asserts that a send-style response carries a campaign/message identifier.
# SMS/MMS responses are CCAI::SMS::Response objects; email responses are hashes.
def assert_send_response!(resp)
  raise 'empty response' if resp.nil?

  if resp.is_a?(Hash)
    id = resp['id'] || resp[:id] || resp['campaignId'] || resp[:campaignId]
    raise "response has no id/campaignId: #{resp.inspect[0, 200]}" if id.nil? || id.to_s.empty?
  else
    id  = resp.respond_to?(:id) ? resp.id : nil
    cid = resp.respond_to?(:campaign_id) ? resp.campaign_id : nil
    raise 'response has no id/campaign_id' if id.to_s.empty? && cid.to_s.empty?
  end
end

# Runs the block and asserts that it raises — used by the negative test cases.
def expect_error!(what)
  begin
    yield
  rescue SkipTest
    raise
  rescue StandardError
    return # failed as expected
  end
  raise "expected #{what} to fail, but it succeeded"
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
  tmp # return the object, not just the path — prevents GC from deleting the file
end

# ── Setup ─────────────────────────────────────────────────────────────────────

# Validate ALL required env vars up front and report every missing one,
# instead of failing later with a cryptic API error.
REQUIRED_ENV = %w[
  CCAI_CLIENT_ID CCAI_API_KEY
  CCAI_TEST_PHONE CCAI_TEST_PHONE_2 CCAI_TEST_PHONE_3
  CCAI_TEST_EMAIL CCAI_TEST_EMAIL_2 CCAI_TEST_EMAIL_3
  CCAI_TEST_FIRST_NAME CCAI_TEST_LAST_NAME
  CCAI_TEST_FIRST_NAME_2 CCAI_TEST_LAST_NAME_2
  CCAI_TEST_FIRST_NAME_3 CCAI_TEST_LAST_NAME_3
  WEBHOOK_URL
].freeze

missing = REQUIRED_ENV.select { |key| ENV[key].nil? || ENV[key].empty? }
unless missing.empty?
  warn "ERROR: required env vars are not set: #{missing.join(', ')}"
  exit 2
end

client_id = ENV.fetch('CCAI_CLIENT_ID')
api_key   = ENV.fetch('CCAI_API_KEY')
phone1    = ENV.fetch('CCAI_TEST_PHONE')
phone2    = ENV.fetch('CCAI_TEST_PHONE_2')
phone3    = ENV.fetch('CCAI_TEST_PHONE_3')
email1    = ENV.fetch('CCAI_TEST_EMAIL')
email2    = ENV.fetch('CCAI_TEST_EMAIL_2')
email3    = ENV.fetch('CCAI_TEST_EMAIL_3')
fn1       = ENV.fetch('CCAI_TEST_FIRST_NAME')
ln1       = ENV.fetch('CCAI_TEST_LAST_NAME')
fn2       = ENV.fetch('CCAI_TEST_FIRST_NAME_2')
ln2       = ENV.fetch('CCAI_TEST_LAST_NAME_2')
fn3       = ENV.fetch('CCAI_TEST_FIRST_NAME_3')
ln3       = ENV.fetch('CCAI_TEST_LAST_NAME_3')

# Unique per-run suffix so parallel SDK runs don't collide on the same webhook URL
run_id       = "ruby-#{Time.now.to_i}"
webhook_base = ENV.fetch('WEBHOOK_URL')
webhook_url  = "#{webhook_base}#{webhook_base.include?('?') ? '&' : '?'}run=#{run_id}"

SENDER_EMAIL   = ENV['CCAI_TEST_SENDER_EMAIL'].to_s.empty? ? 'noreply@cloudcontactai.com' : ENV['CCAI_TEST_SENDER_EMAIL']
REPLY_EMAIL    = SENDER_EMAIL
SENDER_NAME    = 'CCAI Test'
WEBHOOK_SECRET = ENV['CCAI_WEBHOOK_SECRET'].to_s.empty? ? 'test-webhook-secret-ruby' : ENV['CCAI_WEBHOOK_SECRET']

# Use CCAI_BASE_URL if set (local dev), otherwise fall back to test environment
client = CCAI::Client.new(
  CCAI::Config.new(
    client_id: client_id,
    api_key: api_key,
    use_test_environment: ENV['CCAI_BASE_URL'].nil?
  )
)

png_path = write_temp_png

# IDs of resources created by the tests; anything still listed here at the end
# of the run is deleted by the ensure block (tests remove entries they already
# deleted themselves).
cleanup_webhook_ids  = []
cleanup_brand_ids    = []
cleanup_campaign_ids = []

puts '=============================================='
puts '  CCAI Ruby SDK Integration Tests'
puts '=============================================='

begin
  # ── SMS Tests (1-6) ─────────────────────────────────────────────────────────
  puts "\n--- SMS ---"

  # 01 -- SMS.send_single
  run_test('01 SMS.send_single') do
    resp = client.sms.send_single(fn1, ln1, phone1, 'Hello from Ruby SDK!', 'Ruby Test')
    assert_send_response!(resp)
  end

  # 02 -- SMS.send (1 recipient)
  run_test('02 SMS.send (1 recipient)') do
    accounts = [CCAI::SMS::Account.new(first_name: fn1, last_name: ln1, phone: phone1)]
    resp = client.sms.send(accounts, 'Hello 1 recipient!', 'Ruby Test')
    assert_send_response!(resp)
  end

  # 03 -- SMS.send (2 recipients)
  run_test('03 SMS.send (2 recipients)') do
    accounts = [
      CCAI::SMS::Account.new(first_name: fn1, last_name: ln1, phone: phone1),
      CCAI::SMS::Account.new(first_name: fn2, last_name: ln2, phone: phone2)
    ]
    resp = client.sms.send(accounts, 'Hello 2 recipients!', 'Ruby Test')
    assert_send_response!(resp)
  end

  # 04 -- SMS.send (3 recipients)
  run_test('04 SMS.send (3 recipients)') do
    accounts = [
      CCAI::SMS::Account.new(first_name: fn1, last_name: ln1, phone: phone1),
      CCAI::SMS::Account.new(first_name: fn2, last_name: ln2, phone: phone2),
      CCAI::SMS::Account.new(first_name: fn3, last_name: ln3, phone: phone3)
    ]
    resp = client.sms.send(accounts, 'Hello 3 recipients!', 'Ruby Test')
    assert_send_response!(resp)
  end

  # 05 -- SMS.send with data
  run_test('05 SMS.send with data') do
    accounts = [CCAI::SMS::Account.new(first_name: fn1, last_name: ln1, phone: phone1, data: { 'city' => 'Miami', 'offer' => '20% off' })]
    resp = client.sms.send(accounts, 'Hello from ${city}! Claim your ${offer}.', 'Ruby Test Data')
    assert_send_response!(resp)
  end

  # 06 -- SMS.send with custom_data (messageData)
  run_test('06 SMS.send with custom_data') do
    accounts = [CCAI::SMS::Account.new(first_name: fn1, last_name: ln1, phone: phone1, custom_data: '{"trackingId":"ruby-001"}')]
    resp = client.sms.send(accounts, 'Hello with messageData!', 'Ruby Test MsgData')
    assert_send_response!(resp)
  end

  # ── MMS Tests (7-17) ────────────────────────────────────────────────────────
  puts "\n--- MMS ---"

  signed_url_resp = nil
  upload_ok = false

  # 07 -- MMS.get_signed_upload_url
  run_test('07 MMS.get_signed_upload_url') do
    resp = client.mms.get_signed_upload_url('test_image.png', 'image/png')
    raise 'signed_s3_url is empty' if resp.signed_s3_url.to_s.empty?
    raise 'file_key is empty' if resp.file_key.to_s.empty?

    signed_url_resp = resp
  end

  # 08 -- MMS.upload_image_to_signed_url
  run_test('08 MMS.upload_image_to_signed_url') do
    raise SkipTest, 'dependency test 07 failed' if signed_url_resp.nil?

    ok = client.mms.upload_image_to_signed_url(signed_url_resp.signed_s3_url, png_path.path, 'image/png')
    raise 'upload returned false' unless ok

    upload_ok = true
  end

  # 09 -- MMS.send_single
  run_test('09 MMS.send_single') do
    raise SkipTest, 'dependency test 07 failed' if signed_url_resp.nil?

    resp = client.mms.send_single(signed_url_resp.file_key, fn1, ln1, phone1, 'MMS single!', 'Ruby MMS Test')
    assert_send_response!(resp)
  end

  # 10 -- MMS.send (1 recipient)
  run_test('10 MMS.send (1 recipient)') do
    raise SkipTest, 'dependency test 07 failed' if signed_url_resp.nil?

    accounts = [CCAI::SMS::Account.new(first_name: fn1, last_name: ln1, phone: phone1)]
    resp = client.mms.send(signed_url_resp.file_key, accounts, 'MMS 1 recipient!', 'Ruby MMS Test')
    assert_send_response!(resp)
  end

  # 11 -- MMS.send (2 recipients)
  run_test('11 MMS.send (2 recipients)') do
    raise SkipTest, 'dependency test 07 failed' if signed_url_resp.nil?

    accounts = [
      CCAI::SMS::Account.new(first_name: fn1, last_name: ln1, phone: phone1),
      CCAI::SMS::Account.new(first_name: fn2, last_name: ln2, phone: phone2)
    ]
    resp = client.mms.send(signed_url_resp.file_key, accounts, 'MMS 2 recipients!', 'Ruby MMS Test')
    assert_send_response!(resp)
  end

  # 12 -- MMS.send (3 recipients)
  run_test('12 MMS.send (3 recipients)') do
    raise SkipTest, 'dependency test 07 failed' if signed_url_resp.nil?

    accounts = [
      CCAI::SMS::Account.new(first_name: fn1, last_name: ln1, phone: phone1),
      CCAI::SMS::Account.new(first_name: fn2, last_name: ln2, phone: phone2),
      CCAI::SMS::Account.new(first_name: fn3, last_name: ln3, phone: phone3)
    ]
    resp = client.mms.send(signed_url_resp.file_key, accounts, 'MMS 3 recipients!', 'Ruby MMS Test')
    assert_send_response!(resp)
  end

  # 13 -- MMS.send with data
  run_test('13 MMS.send with data') do
    raise SkipTest, 'dependency test 07 failed' if signed_url_resp.nil?

    accounts = [CCAI::SMS::Account.new(first_name: fn1, last_name: ln1, phone: phone1, data: { 'product' => 'Widget' })]
    resp = client.mms.send(signed_url_resp.file_key, accounts, 'Check out ${product}!', 'Ruby MMS Data')
    assert_send_response!(resp)
  end

  # 14 -- MMS.send with custom_data
  run_test('14 MMS.send with custom_data') do
    raise SkipTest, 'dependency test 07 failed' if signed_url_resp.nil?

    accounts = [CCAI::SMS::Account.new(first_name: fn1, last_name: ln1, phone: phone1, custom_data: '{"campaignId":"mms-ruby-001"}')]
    resp = client.mms.send(signed_url_resp.file_key, accounts, 'MMS with messageData!', 'Ruby MMS MsgData')
    assert_send_response!(resp)
  end

  # 15 -- MMS.check_file_uploaded — the file uploaded in test 08 must actually exist
  run_test('15 MMS.check_file_uploaded') do
    raise SkipTest, 'dependency test 07 failed' if signed_url_resp.nil?
    raise SkipTest, 'dependency test 08 failed' unless upload_ok

    resp = client.mms.check_file_uploaded(signed_url_resp.file_key)
    stored = resp.is_a?(Hash) ? (resp['storedUrl'] || resp[:storedUrl]) : nil
    raise "expected non-empty storedUrl for uploaded file #{signed_url_resp.file_key}" if stored.to_s.empty?
  end

  # 16 -- MMS.send_with_image (fresh upload)
  run_test('16 MMS.send_with_image (fresh upload)') do
    accounts = [CCAI::SMS::Account.new(first_name: fn1, last_name: ln1, phone: phone1)]
    resp = client.mms.send_with_image(png_path.path, 'image/png', accounts, 'MMS with image!', 'Ruby MMS Image', nil, nil, true)
    assert_send_response!(resp)
  end

  # 17 -- MMS.send_with_image (cached)
  run_test('17 MMS.send_with_image (cached)') do
    accounts = [CCAI::SMS::Account.new(first_name: fn1, last_name: ln1, phone: phone1)]
    resp = client.mms.send_with_image(png_path.path, 'image/png', accounts, 'MMS cached image!', 'Ruby MMS Cache', nil, nil, true)
    assert_send_response!(resp)
  end

  # ── Email Tests (18-22) ─────────────────────────────────────────────────────
  puts "\n--- Email ---"

  # 18 -- Email.send_single
  run_test('18 Email.send_single') do
    resp = client.email.send_single(
      fn1, ln1, email1,
      'Ruby SDK Test Email', '<p>Hello from Ruby SDK!</p>',
      nil, SENDER_EMAIL, REPLY_EMAIL, SENDER_NAME, 'Ruby Email Test'
    )
    assert_send_response!(resp)
  end

  # 19 -- Email.send (1 recipient)
  run_test('19 Email.send (1 recipient)') do
    accounts = [{ firstName: fn1, lastName: ln1, email: email1, phone: '' }]
    resp = client.email.send(accounts, 'Ruby SDK Email 1', '<p>Hello 1!</p>', SENDER_EMAIL, REPLY_EMAIL, SENDER_NAME, 'Ruby Email Test')
    assert_send_response!(resp)
  end

  # 20 -- Email.send (2 recipients)
  run_test('20 Email.send (2 recipients)') do
    accounts = [
      { firstName: fn1, lastName: ln1, email: email1, phone: '' },
      { firstName: fn2, lastName: ln2, email: email2, phone: '' }
    ]
    resp = client.email.send(accounts, 'Ruby SDK Email 2', '<p>Hello 2!</p>', SENDER_EMAIL, REPLY_EMAIL, SENDER_NAME, 'Ruby Email Test')
    assert_send_response!(resp)
  end

  # 21 -- Email.send (3 recipients)
  run_test('21 Email.send (3 recipients)') do
    accounts = [
      { firstName: fn1, lastName: ln1, email: email1, phone: '' },
      { firstName: fn2, lastName: ln2, email: email2, phone: '' },
      { firstName: fn3, lastName: ln3, email: email3, phone: '' }
    ]
    resp = client.email.send(accounts, 'Ruby SDK Email 3', '<p>Hello 3!</p>', SENDER_EMAIL, REPLY_EMAIL, SENDER_NAME, 'Ruby Email Test')
    assert_send_response!(resp)
  end

  # 22 -- Email.send_campaign (full campaign hash)
  run_test('22 Email.send_campaign') do
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
    resp = client.email.send_campaign(campaign)
    assert_send_response!(resp)
  end

  # ── Webhook Tests (23-29) ───────────────────────────────────────────────────
  puts "\n--- Webhook ---"

  registered_webhook_id = nil

  # 23 -- Webhook.register
  run_test('23 Webhook.register') do
    resp = client.webhook.register(url: webhook_url, secret: WEBHOOK_SECRET)
    id = resp['id'] || resp[:id]
    raise 'webhook ID is empty after register' if id.nil? || id.to_s.empty? || id.to_i.zero?

    registered_webhook_id = id.to_i
    cleanup_webhook_ids << registered_webhook_id
  end

  # 24 -- Webhook.list — must contain the webhook registered in test 23
  run_test('24 Webhook.list') do
    hooks = client.webhook.list
    raise 'expected at least one webhook, got 0' unless hooks.is_a?(Array) && !hooks.empty?

    if registered_webhook_id
      found = hooks.any? { |h| (h['id'] || h[:id]).to_i == registered_webhook_id }
      raise "webhook #{registered_webhook_id} registered in test 23 not present in list" unless found
    end
  end

  # 25 -- Webhook.update — then verify via list that the URL actually changed
  run_test('25 Webhook.update') do
    raise SkipTest, 'dependency test 23 failed' if registered_webhook_id.nil?

    client.webhook.update(registered_webhook_id, url: "#{webhook_url}&updated=1", secret: 'updated-secret-ruby')
    hooks = client.webhook.list
    hook = hooks.find { |h| (h['id'] || h[:id]).to_i == registered_webhook_id }
    raise "webhook #{registered_webhook_id} not found in list after update" if hook.nil?

    url = (hook['url'] || hook[:url]).to_s
    raise "webhook URL was not updated: expected to contain \"updated=1\", got \"#{url}\"" unless url.include?('updated=1')
  end

  # 26 -- Webhook.verify_signature (valid)
  run_test('26 Webhook.verify_signature (valid)') do
    event_hash = 'abc123eventHash'
    sig = hmac_sha256_base64(WEBHOOK_SECRET, "#{client_id}:#{event_hash}")
    ok = client.webhook.verify_signature(sig, client_id, event_hash, WEBHOOK_SECRET)
    raise 'expected valid signature to return true' unless ok
  end

  # 27 -- Webhook.verify_signature (invalid)
  run_test('27 Webhook.verify_signature (invalid)') do
    ok = client.webhook.verify_signature('invalidsig==', client_id, 'somehash', WEBHOOK_SECRET)
    raise 'expected invalid signature to return false' if ok
  end

  # 28 -- Webhook.parse_event
  run_test('28 Webhook.parse_event') do
    payload = '{"eventType":"message.sent","data":{"To":"+15005550001","Message":"test","MessageStatus":"DELIVERED"}}'
    evt = client.webhook.parse_event(payload)
    raise "expected eventType \"message.sent\", got \"#{evt['eventType']}\"" unless evt['eventType'] == 'message.sent'
  end

  # 29 -- Webhook.delete — then verify via list that it is gone
  run_test('29 Webhook.delete') do
    raise SkipTest, 'dependency test 23 failed' if registered_webhook_id.nil?

    client.webhook.delete(registered_webhook_id)
    cleanup_webhook_ids.delete(registered_webhook_id)
    hooks = client.webhook.list
    still_there = hooks.is_a?(Array) && hooks.any? { |h| (h['id'] || h[:id]).to_i == registered_webhook_id }
    raise "webhook #{registered_webhook_id} still present in list after delete" if still_there
  end

  # ── Contact Tests (30-31) ───────────────────────────────────────────────────
  puts "\n--- Contact ---"

  # 30 -- Contact.set_do_not_text(true)
  run_test('30 Contact.set_do_not_text(true)') do
    resp = client.contact.set_do_not_text(true, phone: phone1)
    raise 'empty response' if resp.nil?
  end

  # 31 -- Contact.set_do_not_text(false)
  run_test('31 Contact.set_do_not_text(false)') do
    resp = client.contact.set_do_not_text(false, phone: phone1)
    raise 'empty response' if resp.nil?
  end

  # ── Brands Tests (32-36) ────────────────────────────────────────────────────
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
  run_test('32 Brand.create') do
    resp = client.brand.create(BRAND_PAYLOAD)
    id = resp['id'] || resp[:id]
    raise 'brand ID is empty after create' if id.nil? || id.to_s.empty?

    created_brand_id = id.to_s
    cleanup_brand_ids << created_brand_id
  end

  # 33 -- Brand.get
  run_test('33 Brand.get') do
    raise SkipTest, 'dependency test 32 failed' if created_brand_id.nil?

    resp = client.brand.get(created_brand_id)
    raise 'expected brand response to be a Hash' unless resp.is_a?(Hash)

    id = (resp['id'] || resp[:id]).to_s
    raise "brand id mismatch: expected #{created_brand_id}, got #{id}" unless id == created_brand_id

    name = (resp['legalCompanyName'] || resp[:legalCompanyName]).to_s
    raise "expected legalCompanyName \"Ruby SDK Test Brand LLC\", got \"#{name}\"" unless name == 'Ruby SDK Test Brand LLC'
  end

  # 34 -- Brand.list — must contain the brand created in test 32
  run_test('34 Brand.list') do
    resp = client.brand.list
    raise 'expected list response to be a Hash or Array' unless resp.is_a?(Hash) || resp.is_a?(Array)

    if created_brand_id && resp.is_a?(Array)
      found = resp.any? { |b| (b['id'] || b[:id]).to_s == created_brand_id }
      raise "brand #{created_brand_id} created in test 32 not present in list" unless found
    end
  end

  # 35 -- Brand.update — then verify via get that the field actually changed
  run_test('35 Brand.update') do
    raise SkipTest, 'dependency test 32 failed' if created_brand_id.nil?

    client.brand.update(created_brand_id, { city: 'Fort Lauderdale' })
    fetched = client.brand.get(created_brand_id)
    city = (fetched['city'] || fetched[:city]).to_s
    raise "expected city \"Fort Lauderdale\" after update, got \"#{city}\"" unless city == 'Fort Lauderdale'
  end

  # 36 -- Brand.delete — then verify via get that it is gone
  run_test('36 Brand.delete') do
    raise SkipTest, 'dependency test 32 failed' if created_brand_id.nil?

    client.brand.delete(created_brand_id)
    cleanup_brand_ids.delete(created_brand_id)
    expect_error!("get of deleted brand #{created_brand_id}") { client.brand.get(created_brand_id) }
  end

  # ── Campaigns Tests (37-42) ─────────────────────────────────────────────────
  puts "\n--- Campaigns ---"

  campaign_brand_id = nil
  created_campaign_id = nil

  # 37 -- Campaign setup: create a brand to use
  run_test('37 Campaign setup — Brand.create') do
    resp = client.brand.create(BRAND_PAYLOAD)
    id = resp['id'] || resp[:id]
    raise 'brand ID is empty for campaign setup' if id.nil? || id.to_s.empty?

    campaign_brand_id = id.to_s
    cleanup_brand_ids << campaign_brand_id
  end

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
  run_test('38 Campaign.create') do
    raise SkipTest, 'dependency test 37 failed' if campaign_brand_id.nil?

    payload = CAMPAIGN_PAYLOAD_TEMPLATE.merge(brandId: campaign_brand_id)
    resp = client.campaign.create(payload)
    id = resp['id'] || resp[:id]
    raise 'campaign ID is empty after create' if id.nil? || id.to_s.empty?

    created_campaign_id = id.to_s
    cleanup_campaign_ids << created_campaign_id
  end

  # 39 -- Campaign.get
  run_test('39 Campaign.get') do
    raise SkipTest, 'dependency test 38 failed' if created_campaign_id.nil?

    resp = client.campaign.get(created_campaign_id)
    raise 'expected campaign response to be a Hash' unless resp.is_a?(Hash)

    id = (resp['id'] || resp[:id]).to_s
    raise "campaign id mismatch: expected #{created_campaign_id}, got #{id}" unless id == created_campaign_id

    brand_id = (resp['brandId'] || resp[:brandId]).to_s
    raise "expected brandId #{campaign_brand_id}, got #{brand_id}" unless brand_id == campaign_brand_id
  end

  # 40 -- Campaign.list — must contain the campaign created in test 38
  run_test('40 Campaign.list') do
    resp = client.campaign.list
    raise 'expected list response to be a Hash or Array' unless resp.is_a?(Hash) || resp.is_a?(Array)

    if created_campaign_id && resp.is_a?(Array)
      found = resp.any? { |c| (c['id'] || c[:id]).to_s == created_campaign_id }
      raise "campaign #{created_campaign_id} created in test 38 not present in list" unless found
    end
  end

  # 41 -- Campaign.update — then verify via get that the field actually changed
  run_test('41 Campaign.update') do
    raise SkipTest, 'dependency test 38 failed' if created_campaign_id.nil?

    new_description = 'Updated Ruby SDK campaign'
    client.campaign.update(created_campaign_id, { description: new_description })
    fetched = client.campaign.get(created_campaign_id)
    description = (fetched['description'] || fetched[:description]).to_s
    raise "expected updated description after update, got \"#{description}\"" unless description == new_description
  end

  # 42 -- Campaign.delete — then verify via get that it is gone, and clean up the brand
  run_test('42 Campaign.delete') do
    raise SkipTest, 'dependency test 38 failed' if created_campaign_id.nil?

    client.campaign.delete(created_campaign_id)
    cleanup_campaign_ids.delete(created_campaign_id)
    expect_error!("get of deleted campaign #{created_campaign_id}") { client.campaign.get(created_campaign_id) }

    if campaign_brand_id
      client.brand.delete(campaign_brand_id)
      cleanup_brand_ids.delete(campaign_brand_id)
    end
  end

  # ── ContactValidator Tests (43-46) ──────────────────────────────────────────
  puts "\n--- ContactValidator ---"

  # 43 -- ContactValidator.validate_email
  run_test('43 ContactValidator.validate_email') do
    resp = client.contact_validator.validate_email(email1)
    raise 'status is empty' if resp[:status].to_s.empty?
  end

  # 44 -- ContactValidator.validate_emails
  run_test('44 ContactValidator.validate_emails') do
    resp = client.contact_validator.validate_emails([email1, email2])
    raise "expected summary.total=2, got #{resp.dig(:summary, :total)}" unless resp.dig(:summary, :total) == 2
    raise "expected 2 results, got #{resp[:results]&.size}" unless resp[:results]&.size == 2
  end

  # 45 -- ContactValidator.validate_phone
  run_test('45 ContactValidator.validate_phone') do
    resp = client.contact_validator.validate_phone(phone1)
    raise 'status is empty' if resp[:status].to_s.empty?
  end

  # 46 -- ContactValidator.validate_phones
  run_test('46 ContactValidator.validate_phones') do
    resp = client.contact_validator.validate_phones([{ phone: phone1 }, { phone: phone2 }])
    raise "expected summary.total=2, got #{resp.dig(:summary, :total)}" unless resp.dig(:summary, :total) == 2
    raise "expected 2 results, got #{resp[:results]&.size}" unless resp[:results]&.size == 2
  end

  # ── Negative & Permissive Tests (47-52) ─────────────────────────────────────
  # 47/49/50 PASS when the operation fails as expected. 48/51/52 document
  # permissive behavior observed in the test API: those
  # operations succeed even with invalid input, so the tests assert success.
  puts "\n--- Negative cases ---"

  # 47 -- invalid API key must be rejected
  run_test('47 NEGATIVE: SMS.send_single with invalid API key') do
    bad_client = CCAI::Client.new(
      CCAI::Config.new(
        client_id: client_id,
        api_key: 'invalid-api-key-for-negative-test',
        use_test_environment: ENV['CCAI_BASE_URL'].nil?
      )
    )
    expect_error!('send with invalid API key') do
      bad_client.sms.send_single(fn1, ln1, phone1, 'should fail', 'Ruby Negative 47')
    end
  end

  # 48 -- the test API accepts malformed phone numbers: the
  # send succeeds instead of failing. If the API starts validating phone format,
  # change this back to expect an error.
  run_test('48 PERMISSIVE: SMS.send_single with malformed phone (API accepts)') do
    resp = client.sms.send_single(fn1, ln1, 'abc', 'malformed phone accepted', 'Ruby Permissive 48')
    assert_send_response!(resp)
  end

  # 49 -- getting a nonexistent brand must fail
  run_test('49 NEGATIVE: Brand.get(nonexistent)') do
    expect_error!('get of nonexistent brand') { client.brand.get('99999999') }
  end

  # 50 -- deleting a nonexistent webhook must fail
  run_test('50 NEGATIVE: Webhook.delete(nonexistent)') do
    expect_error!('delete of nonexistent webhook') { client.webhook.delete(99_999_999) }
  end

  # 51 -- the test environment's validator reports "valid" even for syntactically
  # invalid emails — upstream validation is not enforced
  # there, so only assert that a status is returned.
  run_test('51 PERMISSIVE: ContactValidator.validate_email(invalid input)') do
    resp = client.contact_validator.validate_email('not-an-email')
    raise 'status is empty' if resp[:status].to_s.empty?
  end

  # 52 -- the test API accepts MMS sends with a nonexistent fileKey: it does not
  # verify the file exists at send time. If the API
  # starts validating the fileKey, change this back to expect an error.
  run_test('52 PERMISSIVE: MMS.send with nonexistent fileKey (API accepts)') do
    accounts = [CCAI::SMS::Account.new(first_name: fn1, last_name: ln1, phone: phone1)]
    fake_key = "#{client_id}/campaign/nonexistent_#{Time.now.to_i}.png"
    resp = client.mms.send(fake_key, accounts, 'nonexistent fileKey accepted', 'Ruby Permissive 52')
    assert_send_response!(resp)
  end
ensure
  # ── Cleanup — always runs, even if the test body raised ─────────────────────
  cleanup_campaign_ids.each do |id|
    client.campaign.delete(id)
    puts "  CLEANUP: deleted leftover campaign #{id}"
  rescue StandardError => e
    puts "  CLEANUP: could not delete campaign #{id}: #{e.message}"
  end
  cleanup_brand_ids.each do |id|
    client.brand.delete(id)
    puts "  CLEANUP: deleted leftover brand #{id}"
  rescue StandardError => e
    puts "  CLEANUP: could not delete brand #{id}: #{e.message}"
  end
  cleanup_webhook_ids.each do |id|
    client.webhook.delete(id)
    puts "  CLEANUP: deleted leftover webhook #{id}"
  rescue StandardError => e
    puts "  CLEANUP: could not delete webhook #{id}: #{e.message}"
  end
  png_path.close! # cleanup Tempfile
end

# ── Results ───────────────────────────────────────────────────────────────────

puts "\n=============================================="
puts "  RESULTS: #{$passed} passed, #{$failed} failed, #{$skipped} skipped"
puts '=============================================='

summary = JSON.generate({ sdk: 'ruby', passed: $passed, failed: $failed, skipped: $skipped, total: $passed + $failed + $skipped })
puts "\nSUMMARY_JSON: #{summary}"

exit($failed > 0 ? 1 : 0)
