# frozen_string_literal: true

RSpec.describe DiscourseNextcloudOffice::Shares do
  let(:configuration) do
    DiscourseNextcloudOffice::Configuration.new(
      base_url: "https://cloud.example.com",
      username: "office-service",
      app_password: "canary-app-password",
      folder: "Discourse",
    )
  end
  let(:client) do
    DiscourseNextcloudOffice::NextcloudClient.new(
      base_url: configuration.base_url,
      username: configuration.username,
      password: configuration.app_password,
    )
  end
  let(:adapter) { described_class.new(configuration, client: client) }
  let(:path) { "/Discourse/unique-Plan.docx" }
  let(:endpoint) { "https://cloud.example.com#{described_class::ENDPOINT}" }
  let(:share) do
    {
      id: "42",
      path: path,
      uid_owner: "office-service",
      item_type: "file",
      share_type: 3,
      permissions: 3,
      password: nil,
      token: "SyntheticToken123",
      url: "https://cloud.example.com/s/SyntheticToken123",
    }.stringify_keys
  end

  def envelope(data, code: 200)
    { ocs: { meta: { status: "ok", statuscode: code }, data: data } }.to_json
  end

  def stub_creation(data, status: 200)
    stub_request(:post, endpoint).with(query: { format: "json" }).to_return(
      status: status,
      body: data,
    )
  end

  it "creates an editable public file share using JSON and fixed permissions" do
    stub = stub_creation(envelope(share))
    result = adapter.create!(path)
    expect(result).to eq(id: "42", url: share["url"], has_password: false)
    expect(stub).to have_been_requested.once
    expect(
      a_request(:post, endpoint).with(
        query: {
          format: "json",
        },
        headers: {
          "OCS-APIRequest" => "true",
          "Accept" => "application/json",
        },
        body: {
          "path" => path,
          "shareType" => "3",
          "permissions" => "3",
        },
      ),
    ).to have_been_made.once
  end

  it "sets the requested password and accepts only confirmed password protection" do
    protected_share = share.merge("password" => "redacted")
    stub_creation(envelope(protected_share))
    result = adapter.create!(path, password: "canary-share-password")
    expect(result[:has_password]).to eq(true)
    expect(
      a_request(:post, endpoint).with(
        query: {
          format: "json",
        },
        body: hash_including("password" => "canary-share-password"),
      ),
    ).to have_been_made.once
  end

  it "never retries a failed password-policy request without its password" do
    stub = stub_creation(envelope({}, code: 403))
    expect { adapter.create!(path, password: "canary-share-password") }.to raise_error(
      DiscourseNextcloudOffice::NextcloudError,
      "share_request_failed",
    )
    expect(stub).to have_been_requested.once
  end

  it "rejects false password confirmation or an unknown password field" do
    [nil, false, "hash-or-plaintext"].each do |value|
      stub_creation(envelope(share.merge("password" => value)))
      expect { adapter.create!(path, password: "secret") }.to raise_error(
        DiscourseNextcloudOffice::NextcloudError,
        "share_password_mismatch",
      )
    end
  end

  it "rejects wrong path, owner, type, permissions and missing IDs" do
    [
      { "path" => "/someone-else.docx" },
      { "uid_owner" => "other" },
      { "share_type" => 0 },
      { "permissions" => 31 },
      { "item_type" => "folder" },
      { "id" => nil },
    ].each do |change|
      stub_creation(envelope(share.merge(change)))
      expect { adapter.create!(path) }.to raise_error(
        DiscourseNextcloudOffice::NextcloudError,
        "invalid_share_response",
      )
    end
  end

  it "rejects unsafe URLs without fetching them" do
    %w[
      https://attacker.example/s/SyntheticToken123
      http://cloud.example.com/s/SyntheticToken123
      https://user:pass@cloud.example.com/s/SyntheticToken123
      https://cloud.example.com/s/other
      https://cloud.example.com/s/SyntheticToken123?x=1
      https://cloud.example.com/s/SyntheticToken123#fragment
      javascript:alert(1)
    ].each do |url|
      stub_creation(envelope(share.merge("url" => url)))
      expect { adapter.create!(path) }.to raise_error(
        DiscourseNextcloudOffice::NextcloudError,
        "invalid_share_url",
      )
    end
    expect(a_request(:get, /attacker.example/)).not_to have_been_made
  end

  it "accepts index.php share routes on the configured origin" do
    stub_creation(
      envelope(share.merge("url" => "https://cloud.example.com/index.php/s/SyntheticToken123")),
    )
    expect(adapter.create!(path)[:id]).to eq("42")
  end

  it "rejects HTTP failures, malformed JSON and XML instead of falling back" do
    stub_creation(envelope(share), status: 500)
    expect { adapter.create!(path) }.to raise_error(
      DiscourseNextcloudOffice::NextcloudError,
      "share_request_failed",
    )
    ["<ocs>not JSON</ocs>", "null", "[]", '{"ocs":null}'].each do |body|
      stub_creation(body)
      expect { adapter.create!(path) }.to raise_error(DiscourseNextcloudOffice::NextcloudError)
    end
  end

  it "finds an existing share by exclusive path without issuing a mutation" do
    stub_request(:get, endpoint).with(
      query: {
        format: "json",
        path: path,
        reshares: "false",
        subfiles: "false",
      },
    ).to_return(body: envelope([share]))
    expect(adapter.find(path, password_required: false)).to eq(
      id: "42",
      url: share["url"],
      has_password: false,
    )
    expect(a_request(:post, /.*/)).not_to have_been_made
    expect(a_request(:delete, /.*/)).not_to have_been_made
  end

  it "distinguishes no existing share from ambiguous recovery" do
    query = { format: "json", path: path, reshares: "false", subfiles: "false" }
    stub_request(:get, endpoint).with(query: query).to_return(body: envelope([]))
    expect(adapter.find(path, password_required: false)).to be_nil
    stub_request(:get, endpoint).with(query: query).to_return(
      body: envelope([share, share.merge("id" => "43")]),
    )
    expect { adapter.find(path, password_required: false) }.to raise_error(
      DiscourseNextcloudOffice::NextcloudError,
      "ambiguous_share",
    )
  end

  it "keeps upstream diagnostics and secrets out of exception text" do
    stub_creation(envelope({ secret: "canary-upstream-secret" }, code: 403))
    logger =
      track_log_messages do
        expect { adapter.create!(path, password: "canary-share-password") }.to raise_error(
          DiscourseNextcloudOffice::NextcloudError,
          "share_request_failed",
        )
      end
    expect((logger.infos + logger.warnings + logger.errors).join).not_to include("canary")
  end
end
