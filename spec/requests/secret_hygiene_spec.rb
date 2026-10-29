# frozen_string_literal: true

RSpec.describe "Nextcloud Office secret hygiene" do
  include OfficePackageHelpers
  include OfficeNextcloudHelpers

  fab!(:user)

  let(:app_password) { "canary-app-password-4c1d" }
  let(:share_password) { "canary-share-password-77ab" }

  before do
    enable_current_plugin
    SiteSetting.nextcloud_office_base_url = "https://cloud.example.com"
    SiteSetting.nextcloud_office_username = "canary-service-account"
    SiteSetting.nextcloud_office_app_password = app_password
    SiteSetting.nextcloud_office_folder = "Community/Discourse"
    SiteSetting.authorized_extensions = "jpg|png|docx|xlsx|pptx|odt|ods|odp"
    sign_in(user)
    stub_office_nextcloud(username: "canary-service-account")
  end

  after { cleanup_office_packages }

  # Captures Rails broadcasts, not the persisted Logster store or proxy logs.
  def log_messages(logger)
    logger.debugs + logger.infos + logger.warnings + logger.errors + logger.fatals
  end

  def expect_no_canary(text)
    expect(text).not_to include(app_password)
    expect(text).not_to include(share_password)
    expect(text).not_to include("canary-service-account")
    expect(text).not_to include("canary-file-content")
  end

  it "keeps credentials out of the client settings payload" do
    get "/site/settings.json"

    expect(response.status).to eq(200)
    expect(response.body).to include("nextcloud_office_enabled")
    expect_no_canary(response.body)
  end

  it "keeps credentials out of HTML page preloads" do
    get "/latest"

    expect(response.status).to eq(200)
    expect_no_canary(response.body)
  end

  it "keeps the share password out of responses and request logs" do
    logger =
      track_log_messages do
        post "/nextcloud-office/documents.json",
             params: {
               file_name: "Plan.docx",
               file_type: "docx",
               operation_key: "op-1",
               share_password: share_password,
             },
             as: :json
      end

    expect(response.status).to eq(200)
    expect(response.parsed_body.keys).to contain_exactly(
      "success",
      "operation_key",
      "url",
      "file_name",
      "file_type",
      "has_password",
    )
    expect_no_canary(response.body)
    expect(log_messages(logger)).to all(
      satisfy { |message| !message.to_s.include?(share_password) },
    )
  end

  it "keeps an invalid share password out of responses and logs" do
    logger =
      track_log_messages do
        post "/nextcloud-office/documents.json",
             params: {
               file_name: "Plan.docx",
               file_type: "docx",
               operation_key: "op-1",
               share_password: "#{share_password}\n",
             },
             as: :json
      end

    expect(response.status).to eq(400)
    expect(response.parsed_body["error_code"]).to eq("invalid_share_password")
    expect_no_canary(response.body)
    expect(log_messages(logger)).to all(
      satisfy { |message| !message.to_s.include?(share_password) },
    )
  end

  it "keeps file contents and parameters out of logs when the package is rejected" do
    canary_file = build_office_package({ "readme.txt" => "canary-file-content" })

    logger =
      track_log_messages do
        post "/nextcloud-office/transfers.json",
             params: {
               file: Rack::Test::UploadedFile.new(canary_file, "application/zip"),
               file_name: "Plan.docx",
               file_type: "docx",
               operation_key: "op-1",
             }
      end

    expect(response.status).to eq(415)
    expect(response.parsed_body["error_code"]).to eq("invalid_file_content")
    expect_no_canary(response.body)
    expect(log_messages(logger)).to all(satisfy { |message| !message.to_s.include?("canary") })
  end

  it "does not expose credentials in status lookups" do
    get "/nextcloud-office/operations/op-1.json"

    expect(response.status).to eq(404)
    expect(response.parsed_body.keys).to contain_exactly(
      "success",
      "error_code",
      "error",
      "correlation_id",
    )
    expect_no_canary(response.body)
  end

  it "keeps credentials out of a configuration failure response" do
    SiteSetting.nextcloud_office_username = ""

    post "/nextcloud-office/documents.json",
         params: {
           file_name: "Plan.docx",
           file_type: "docx",
           operation_key: "op-1",
         },
         as: :json

    expect(response.status).to eq(503)
    expect_no_canary(response.body)
  end
end
