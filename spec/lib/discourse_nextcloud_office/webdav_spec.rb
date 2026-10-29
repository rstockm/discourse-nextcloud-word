# frozen_string_literal: true

RSpec.describe DiscourseNextcloudOffice::Webdav do
  let(:configuration) do
    DiscourseNextcloudOffice::Configuration.new(
      base_url: "https://cloud.example.com",
      username: "office-service",
      app_password: "synthetic-password",
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
  let(:path) { adapter.allocate_path("Plan.docx") }
  let(:url) { "https://cloud.example.com/remote.php/dav/files/office-service#{path}" }

  it "allocates distinct paths for equal names without losing the display name" do
    paths = Array.new(20) { adapter.allocate_path("Änderung.docx") }
    expect(paths.uniq.size).to eq(20)
    expect(paths).to all(end_with("-Änderung.docx"))
  end

  it "creates only with If-None-Match and accepts only a 201" do
    stub =
      stub_request(:put, url).with(
        headers: {
          "If-None-Match" => "*",
        },
        body: "synthetic document",
      ).to_return(status: 201, headers: { "ETag" => '"version-1"' })

    result = adapter.create!(path, source: StringIO.new("synthetic document"), file_type: "docx")

    expect(result).to eq(path: path, etag: '"version-1"')
    expect(stub).to have_been_requested.once
  end

  it "returns a controlled conflict for an existing file without retrying" do
    stub = stub_request(:put, url).to_return(status: 412)
    expect { adapter.create!(path, source: "bytes", file_type: "docx") }.to raise_error(
      DiscourseNextcloudOffice::NextcloudError,
      "file_conflict",
    )
    expect(stub).to have_been_requested.once
  end

  it "allows only one concurrent creation at the same path" do
    lock = Mutex.new
    exists = false
    stub_request(:put, url)
      .with(headers: { "If-None-Match" => "*" })
      .to_return do
        lock.synchronize do
          status = exists ? 412 : 201
          exists = true
          { status: status }
        end
      end
    target = path
    results =
      2
        .times
        .map do
          Thread.new do
            adapter.create!(target, source: "bytes", file_type: "docx")
            :created
          rescue DiscourseNextcloudOffice::NextcloudError => error
            error.error_code
          end
        end
        .map(&:value)

    expect(results).to contain_exactly(:created, "file_conflict")
  end

  it "does not accept 204 or retry unknown outcomes" do
    [204, 500].each do |status|
      stub = stub_request(:put, url).to_return(status: status)
      expect { adapter.create!(path, source: "bytes", file_type: "docx") }.to raise_error(
        DiscourseNextcloudOffice::NextcloudError,
        "file_outcome_unknown",
      )
      expect(stub).to have_been_requested.once
      WebMock.reset!
    end
  end

  it "marks a lost PUT response as unknown instead of retrying or deleting" do
    stub = stub_request(:put, url).to_timeout
    expect { adapter.create!(path, source: "bytes", file_type: "docx") }.to raise_error(
      DiscourseNextcloudOffice::NextcloudError,
      "file_outcome_unknown",
    )
    expect(stub).to have_been_requested.once
    expect(a_request(:delete, /.*/)).not_to have_been_made
  end

  it "encodes Unicode, percent signs and reserved characters per path segment" do
    name = "Änderung 50% #1.docx"
    target = adapter.allocate_path(name)
    encoded = URI.encode_www_form_component(target.split("/").last).gsub("+", "%20")
    stub =
      stub_request(
        :put,
        "https://cloud.example.com/remote.php/dav/files/office-service/Discourse/#{encoded}",
      ).to_return(status: 201)

    adapter.create!(target, source: "bytes", file_type: "docx")
    expect(stub).to have_been_requested.once
  end

  it "refuses traversal and paths outside the configured folder before sending" do
    %w[/Elsewhere/file.docx /Discourse/../file.docx /Discourse//file.docx].each do |target|
      expect { adapter.create!(target, source: "bytes", file_type: "docx") }.to raise_error(
        DiscourseNextcloudOffice::NextcloudError,
        "invalid_request_path",
      )
    end
    expect(a_request(:any, /cloud.example.com/)).not_to have_been_made
  end

  it "reports missing files and metadata without mutation" do
    stub_request(:head, url).to_return(status: 404)
    expect(adapter.stat(path)).to be_nil
    stub_request(:head, url).to_return(
      status: 200,
      headers: {
        "ETag" => '"v2"',
        "Content-Length" => "20",
      },
    )
    expect(adapter.stat(path)).to eq(etag: '"v2"', size: 20)
    expect(a_request(:put, /.*/)).not_to have_been_made
  end
end
