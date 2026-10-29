# frozen_string_literal: true

RSpec.describe "Office document operations" do
  include OfficePackageHelpers
  include OfficeNextcloudHelpers
  fab!(:user)
  fab!(:other_user, :user)

  before do
    enable_current_plugin
    SiteSetting.nextcloud_office_base_url = "https://cloud.example.com"
    SiteSetting.nextcloud_office_username = "office-service"
    SiteSetting.nextcloud_office_app_password = "synthetic-app-password"
    SiteSetting.authorized_extensions = "docx|xlsx|pptx|odt|ods|odp"
    stub_office_nextcloud
    sign_in(user)
  end

  after { cleanup_office_packages }

  def create_document(overrides = {})
    post "/nextcloud-office/documents.json",
         params: { file_name: "Plan.docx", file_type: "docx", operation_key: "op-1" }.merge(
           overrides,
         ),
         as: :json
  end

  it "creates all three templates and returns the display name with editable links" do
    %w[docx xlsx pptx].each do |format|
      create_document(
        file_name: "Plan.#{format}",
        file_type: format,
        operation_key: "template-#{format}",
      )
      expect(response.status).to eq(200)
      body = response.parsed_body
      expect(body["success"]).to eq(true)
      expect(body["file_name"]).to eq("Plan.#{format}")
      expect(body["url"]).to start_with("https://cloud.example.com/s/")
      expect(response.headers["Cache-Control"]).to include("no-store")
    end
    expect(@office_files.keys.grep(/-Plan\.(docx|xlsx|pptx)\z/).size).to eq(3)
    expect(@office_files.size).to eq(3)
    expect(@office_shares.values.flatten.size).to eq(3)
  end

  it "transfers all six formats without using a template" do
    %w[docx xlsx pptx odt ods odp].each do |format|
      post "/nextcloud-office/transfers.json",
           params: {
             file: Rack::Test::UploadedFile.new(office_fixture_path("upload.#{format}")),
             file_name: "Upload.#{format}",
             file_type: format,
             operation_key: "upload-#{format}",
           }
      expect(response.status).to eq(200)
      expect(response.parsed_body["file_type"]).to eq(format)
      stored = @office_files.find { |path, _| path.end_with?("-Upload.#{format}") }.last
      expect(Digest::SHA256.hexdigest(stored)).to eq(
        Digest::SHA256.file(office_fixture_path("upload.#{format}")).hexdigest,
      )
    end
  end

  it "keeps same-named parallel uploads distinct instead of overwriting" do
    %w[first second].each do |key|
      post "/nextcloud-office/transfers.json", params: {
        file: Rack::Test::UploadedFile.new(office_fixture_path("upload.docx")),
        file_name: "Same.docx",
        file_type: "docx",
        operation_key: key,
      }
      expect(response.status).to eq(200)
    end

    expect(@office_files.keys.grep(/-Same\.docx\z/).size).to eq(2)
    expect(@office_files.values.map { |bytes| Digest::SHA256.hexdigest(bytes) }.uniq.size).to eq(1)
    expect(@office_shares.values.flatten.size).to eq(2)
  end

  it "replays completed requests without another mutation and rejects changed passwords" do
    create_document(share_password: "synthetic-password")
    original = response.parsed_body
    create_document(share_password: "synthetic-password")
    expect(response.parsed_body).to eq(original)
    expect(@office_files.size).to eq(1)
    expect(@office_share_id).to eq(1)
    create_document(share_password: "different-password")
    expect(response.status).to eq(409)
    expect(response.parsed_body["error_code"]).to eq("operation_conflict")
  end

  it "returns results only to the operation owner" do
    create_document
    original = response.parsed_body
    get "/nextcloud-office/operations/op-1.json"
    expect(response.parsed_body).to eq(original)
    expect(response.headers["Cache-Control"]).to include("no-store")

    sign_in(other_user)
    get "/nextcloud-office/operations/op-1.json"
    expect(response.status).to eq(404)
    expect(response.body).not_to include(original["url"])
  end

  it "recovers a PUT committed before its response was lost" do
    create_document
    operation = DiscourseNextcloudOffice::Operation.last
    original = response.parsed_body
    operation.update!(state: "unknown", encrypted_result: nil, completed_at: nil)

    create_document

    expect(response.parsed_body).to eq(original)
    expect(@office_files.size).to eq(1)
    expect(@office_share_id).to eq(1)
  end

  it "handles a real transport timeout after PUT commit without another PUT" do
    calls = 0
    stub_request(:put, %r{/remote.php/dav/files/office-service/}).to_return do |request|
      calls += 1
      path =
        URI::DEFAULT_PARSER.unescape(
          request.uri.path.delete_prefix("/remote.php/dav/files/office-service"),
        )
      @office_files[path] = request.body
      raise Net::ReadTimeout, "synthetic lost response"
    end

    create_document
    expect(response.status).to eq(502)
    expect(DiscourseNextcloudOffice::Operation.last.state).to eq("unknown")
    create_document
    expect(response.status).to eq(200)
    expect(calls).to eq(1)
    expect(@office_share_id).to eq(1)
  end

  it "keeps malformed share responses unresolved without publishing or deleting" do
    stub_request(:post, %r{/ocs/v2.php/apps/files_sharing/api/v1/shares}).to_return(
      status: 200,
      body: office_ocs_envelope({ "url" => "https://attacker.example/" }),
    )
    create_document
    expect(response.status).to eq(502)
    expect(response.body).not_to include("attacker.example")
    expect(DiscourseNextcloudOffice::Operation.last.state).to eq("file_created")
    expect(@office_files.size).to eq(1)
    expect(a_request(:delete, /.*/)).not_to have_been_made
  end

  it "recovers a lost share response by lookup without creating another share" do
    create_document(share_password: "synthetic-password")
    operation = DiscourseNextcloudOffice::Operation.last
    original = response.parsed_body
    operation.update!(state: "file_created", encrypted_result: nil, completed_at: nil)

    create_document(share_password: "synthetic-password")

    expect(response.parsed_body).to eq(original)
    expect(@office_share_id).to eq(1)
  end

  it "recovers a share committed before a real transport timeout" do
    calls = 0
    stub_request(:post, %r{/ocs/v2.php/apps/files_sharing/api/v1/shares}).to_return do |request|
      calls += 1
      fields = URI.decode_www_form(request.body).to_h
      @office_shares[fields.fetch("path")] = [{
        "id" => "42", "path" => fields.fetch("path"), "uid_owner" => "office-service",
        "item_type" => "file", "share_type" => 3, "permissions" => 3,
        "password" => "redacted", "token" => "RecoveredToken",
        "url" => "https://cloud.example.com/s/RecoveredToken",
      }]
      raise Net::ReadTimeout, "synthetic lost share response"
    end
    create_document(share_password: "synthetic-password")
    expect(response.status).to eq(502)
    expect(response.body).not_to include("RecoveredToken")

    create_document(share_password: "synthetic-password")

    expect(response.status).to eq(200)
    expect(response.parsed_body["url"]).to eq("https://cloud.example.com/s/RecoveredToken")
    expect(calls).to eq(1)
  end

  it "keeps an altered remote document instead of overwriting or deleting it" do
    create_document
    operation = DiscourseNextcloudOffice::Operation.last
    operation.update!(state: "unknown", encrypted_result: nil, completed_at: nil)
    @office_files[operation.target_path] = "edited by someone else"

    create_document

    expect(response.status).to eq(409)
    expect(@office_files[operation.target_path]).to eq("edited by someone else")
    expect(a_request(:delete, /.*/)).not_to have_been_made
  end

  it "retains the original upload on rejection, with no remote file or template fallback" do
    post "/nextcloud-office/transfers.json",
         params: {
           file_name: "Missing.docx",
           file_type: "docx",
           operation_key: "missing-file",
         },
         as: :json
    expect(response.status).to eq(400)
    expect(@office_files).to be_empty
  end
end
