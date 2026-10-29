# frozen_string_literal: true

RSpec.describe DiscourseNextcloudOffice::OperationsController do
  include OfficePackageHelpers
  include OfficeNextcloudHelpers

  fab!(:user)

  before do
    enable_current_plugin
    SiteSetting.nextcloud_office_base_url = "https://cloud.example.com"
    SiteSetting.nextcloud_office_username = "office-service"
    SiteSetting.nextcloud_office_app_password = "synthetic-app-password"
    SiteSetting.nextcloud_office_folder = "Community/Discourse"
    SiteSetting.authorized_extensions = "jpg|png|docx|xlsx|pptx|odt|ods|odp"
    stub_office_nextcloud
  end

  after { cleanup_office_packages }

  def submit_document
    post "/nextcloud-office/documents.json",
         params: {
           file_name: "Plan.docx",
           file_type: "docx",
           operation_key: "op-1",
         },
         as: :json
  end

  def expect_safe_error(status:, error_code:)
    expect(response.status).to eq(status)
    body = response.parsed_body
    expect(body["success"]).to eq(false)
    expect(body["error_code"]).to eq(error_code)
    expect(body["correlation_id"]).to be_present
    expect(response.headers["X-Discourse-Office-Correlation-Id"]).to eq(body["correlation_id"])
    expect(response.headers["Cache-Control"]).to include("no-store")
    expect(response.body).not_to include("synthetic-app-password")
    expect(response.body).not_to include("office-service")
    body
  end

  def expect_created
    expect(response.status).to eq(200)
    expect(response.parsed_body["success"]).to eq(true)
    expect(response.parsed_body["url"]).to start_with("https://cloud.example.com/s/")
    expect(response.headers["Cache-Control"]).to include("no-store")
  end

  describe "authentication and account state" do
    it "rejects anonymous requests before doing any work" do
      submit_document

      expect_safe_error(status: 403, error_code: "not_logged_in")
    end

    it "rejects a suspended session" do
      sign_in(user)
      user.update_columns(suspended_at: Time.zone.now, suspended_till: 1.day.from_now)

      submit_document

      expect(response.status).to eq(403)
      expect(response.parsed_body["success"]).to eq(false)
    end

    it "rejects a deactivated session" do
      sign_in(user)
      user.update_columns(active: false)

      submit_document

      expect(response.status).to eq(403)
      expect(response.parsed_body["success"]).to eq(false)
    end

    it "rejects API-key authentication even for an active account" do
      api_key = Fabricate(:api_key, user: user)

      post "/nextcloud-office/documents.json",
           params: {
             file_name: "Plan.docx",
             file_type: "docx",
             operation_key: "op-1",
           },
           headers: {
             "Api-Key" => api_key.key,
             "Api-Username" => user.username,
           },
           as: :json

      expect_safe_error(status: 403, error_code: "session_required")
    end
  end

  describe "plugin and configuration state" do
    it "returns 404 when the plugin is disabled" do
      sign_in(user)
      SiteSetting.nextcloud_office_enabled = false

      submit_document

      expect(response.status).to eq(404)
    end

    it "returns 503 while the connection is not configured" do
      sign_in(user)
      SiteSetting.nextcloud_office_app_password = ""

      submit_document

      expect_safe_error(status: 503, error_code: "not_configured")
    end

    it "returns 503 for a non-HTTPS base URL" do
      sign_in(user)
      SiteSetting.nextcloud_office_base_url = "http://cloud.example.com"

      submit_document

      expect_safe_error(status: 503, error_code: "not_configured")
    end
  end

  describe "parameter and format validation" do
    before { sign_in(user) }

    it "rejects external download parameters at the public boundary" do
      post "/nextcloud-office/documents.json",
           params: {
             file_name: "Plan.docx",
             file_type: "docx",
             operation_key: "op-1",
             downloadUrl: "https://attacker.example/document.docx",
           },
           as: :json

      expect_safe_error(status: 400, error_code: "invalid_parameters")
      expect(a_request(:any, /attacker\.example/)).not_to have_been_made
    end

    it "rejects arrays instead of strings" do
      post "/nextcloud-office/documents.json",
           params: {
             file_name: ["Plan.docx"],
             file_type: "docx",
             operation_key: "op-1",
           },
           as: :json

      expect_safe_error(status: 400, error_code: "invalid_parameters")
    end

    it "rejects unsupported formats and mismatched extensions" do
      post "/nextcloud-office/documents.json",
           params: {
             file_name: "Plan.docx",
             file_type: "exe",
             operation_key: "op-1",
           },
           as: :json
      expect_safe_error(status: 415, error_code: "unsupported_file_type")

      post "/nextcloud-office/documents.json",
           params: {
             file_name: "Plan.xlsx",
             file_type: "docx",
             operation_key: "op-1",
           },
           as: :json
      expect_safe_error(status: 400, error_code: "file_extension_mismatch")
    end

    it "rejects invalid operation keys and unsafe passwords without echoing them" do
      post "/nextcloud-office/documents.json",
           params: {
             file_name: "Plan.docx",
             file_type: "docx",
             operation_key: "../op-1",
           },
           as: :json
      expect_safe_error(status: 400, error_code: "invalid_operation_key")

      post "/nextcloud-office/documents.json",
           params: {
             file_name: "Plan.docx",
             file_type: "docx",
             operation_key: "op-1",
             share_password: "canary-password\n",
           },
           as: :json

      body = expect_safe_error(status: 400, error_code: "invalid_share_password")
      expect(response.body).not_to include("canary-password")
      expect(body["error"]).to be_present
    end

    it "does not echo HTML from invalid file names" do
      post "/nextcloud-office/documents.json",
           params: {
             file_name: "<img src=x onerror=alert(1)>.docx",
             file_type: "docx",
             operation_key: "op-1",
           },
           as: :json

      post "/nextcloud-office/documents.json",
           params: {
             file_name: "<img src=x onerror=alert(1)>",
             file_type: "docx",
             operation_key: "op-1",
           },
           as: :json

      expect_created
      expect(response.body).not_to include("<img")
    end

    it "requires a multipart file for transfers" do
      post "/nextcloud-office/transfers.json",
           params: {
             file_name: "Plan.docx",
             file_type: "docx",
             operation_key: "op-1",
           },
           as: :json

      expect_safe_error(status: 400, error_code: "invalid_parameters")
    end

    it "accepts a structurally valid upload and rejects a generic ZIP" do
      file =
        Rack::Test::UploadedFile.new(
          office_fixture_path("upload.docx"),
          DiscourseNextcloudOffice::OfficeFormat.mime_type("docx"),
        )
      post "/nextcloud-office/transfers.json",
           params: {
             file: file,
             file_name: "Plan.docx",
             file_type: "docx",
             operation_key: "op-1",
           }
      expect_created

      fake =
        Rack::Test::UploadedFile.new(
          build_office_package({ "readme.txt" => "nope" }),
          "application/zip",
        )
      post "/nextcloud-office/transfers.json",
           params: {
             file: fake,
             file_name: "Plan.docx",
             file_type: "docx",
             operation_key: "op-1",
           }
      expect_safe_error(status: 415, error_code: "invalid_file_content")
    end
  end

  describe "resource limits" do
    before do
      sign_in(user)
      RateLimiter.enable
      RateLimiter.clear_all_global!
      DiscourseNextcloudOffice::RateLimits.clear_slots!
    end

    after do
      RateLimiter.disable
      RateLimiter.clear_all_global!
      DiscourseNextcloudOffice::RateLimits.clear_slots!
      SiteSetting.max_attachment_size_kb = 10_240
    end

    def upload_fixture(name = "upload.docx", format: "docx")
      Rack::Test::UploadedFile.new(
        office_fixture_path(name),
        DiscourseNextcloudOffice::OfficeFormat.mime_type(format),
      )
    end

    it "rejects an oversized JSON body with 413 before parsing it" do
      post "/nextcloud-office/documents.json",
           params: {
             file_name: "Plan.docx",
             file_type: "docx",
             operation_key: "op-1",
             padding: "x" * (DiscourseNextcloudOffice::Limits::JSON_BODY_BYTES + 1),
           },
           as: :json

      expect_safe_error(status: 413, error_code: "request_too_large")
    end

    it "rejects an oversized file with 413 before validating its content" do
      SiteSetting.nextcloud_office_max_file_size_mb = 1
      oversized = Tempfile.new(%w[oversized .docx])
      oversized.write("x" * (1.megabyte + 1))
      oversized.flush
      allow(DiscourseNextcloudOffice::PackageValidator).to receive(:validate!).and_call_original

      post "/nextcloud-office/transfers.json",
           params: {
             file: Rack::Test::UploadedFile.new(oversized.path, "application/octet-stream"),
             file_name: "Plan.docx",
             file_type: "docx",
             operation_key: "op-1",
           }

      expect_safe_error(status: 413, error_code: "file_too_large")
      expect(DiscourseNextcloudOffice::PackageValidator).not_to have_received(:validate!)
    ensure
      oversized&.close!
    end

    it "respects the site's attachment limit" do
      SiteSetting.nextcloud_office_max_file_size_mb = 25
      SiteSetting.max_attachment_size_kb = 1

      post "/nextcloud-office/transfers.json",
           params: {
             file: upload_fixture,
             file_name: "Plan.docx",
             file_type: "docx",
             operation_key: "op-1",
           }

      expect_safe_error(status: 413, error_code: "file_too_large")
    end

    it "accepts a file that fits the site's attachment limit" do
      SiteSetting.nextcloud_office_max_file_size_mb = 25
      SiteSetting.max_attachment_size_kb = 10

      post "/nextcloud-office/transfers.json",
           params: {
             file: upload_fixture,
             file_name: "Plan.docx",
             file_type: "docx",
             operation_key: "op-1",
           }

      expect_created
    end

    it "refuses formats the site does not allow for uploads" do
      SiteSetting.authorized_extensions = "jpg|png"
      allow(DiscourseNextcloudOffice::PackageValidator).to receive(:validate!).and_call_original

      post "/nextcloud-office/transfers.json",
           params: {
             file: upload_fixture,
             file_name: "Plan.docx",
             file_type: "docx",
             operation_key: "op-1",
           }

      expect_safe_error(status: 415, error_code: "file_type_not_allowed")
      expect(DiscourseNextcloudOffice::PackageValidator).not_to have_received(:validate!)
    end

    it "returns 429 with a retry hint once the per-user budget is used up" do
      5.times { submit_document }
      expect(response.status).to eq(200)

      submit_document

      expect_safe_error(status: 429, error_code: "rate_limited")
      expect(response.headers["Retry-After"].to_i).to be > 0
    end

    it "does not start work when the user's concurrency slots are taken" do
      2.times do |index|
        Discourse.redis.zadd(
          "#{DiscourseNextcloudOffice::RateLimits::SLOT_PREFIX}:user:#{user.id}",
          Time.now.to_i + 120,
          "seed-#{index}",
        )
      end
      allow(DiscourseNextcloudOffice::PackageValidator).to receive(:validate!).and_call_original

      post "/nextcloud-office/transfers.json",
           params: {
             file: upload_fixture,
             file_name: "Plan.docx",
             file_type: "docx",
             operation_key: "op-1",
           }

      expect_safe_error(status: 429, error_code: "too_many_concurrent")
      expect(DiscourseNextcloudOffice::PackageValidator).not_to have_received(:validate!)
    end

    it "releases the operation slot after a rejected request" do
      submit_document
      expect(response.status).to eq(200)

      expect(DiscourseNextcloudOffice::RateLimits.slot_count("user:#{user.id}")).to eq(0)
      expect(DiscourseNextcloudOffice::RateLimits.slot_count("instance")).to eq(0)
    end

    it "rate limits status lookups separately from mutations" do
      30.times { get "/nextcloud-office/operations/op-1.json" }
      expect(response.status).to eq(404)

      get "/nextcloud-office/operations/op-1.json"

      expect_safe_error(status: 429, error_code: "rate_limited")
    end
  end

  describe "CSRF protection" do
    before { ActionController::Base.allow_forgery_protection = true }
    after { ActionController::Base.allow_forgery_protection = false }

    it "rejects a session request with a forged origin and no token" do
      sign_in(user)

      post "/nextcloud-office/documents.json",
           params: {
             file_name: "Plan.docx",
             file_type: "docx",
             operation_key: "op-1",
           },
           headers: {
             "Origin" => "https://attacker.example",
           },
           as: :json

      expect_safe_error(status: 403, error_code: "csrf_failed")
    end

    it "accepts a request with a valid session and CSRF token" do
      sign_in(user)
      get "/session/csrf.json"
      token = response.parsed_body["csrf"]

      post "/nextcloud-office/documents.json",
           params: {
             file_name: "Plan.docx",
             file_type: "docx",
             operation_key: "op-1",
           },
           headers: {
             "X-CSRF-Token" => token,
           },
           as: :json

      expect_created
    end
  end

  describe "operation status endpoint" do
    it "rejects anonymous status requests" do
      get "/nextcloud-office/operations/op-1.json"

      expect_safe_error(status: 403, error_code: "not_logged_in")
    end

    it "does not reveal unknown or foreign operations" do
      sign_in(user)

      get "/nextcloud-office/operations/another-user-op.json"

      expect_safe_error(status: 404, error_code: "operation_not_found")
    end

    it "checks configuration before looking up an operation" do
      sign_in(user)
      SiteSetting.nextcloud_office_username = ""

      get "/nextcloud-office/operations/op-1.json"

      expect_safe_error(status: 503, error_code: "not_configured")
    end
  end
end
