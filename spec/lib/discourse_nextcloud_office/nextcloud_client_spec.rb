# frozen_string_literal: true

RSpec.describe DiscourseNextcloudOffice::NextcloudClient do
  let(:base_url) { "https://cloud.example.com" }
  let(:password) { "canary-app-password" }
  let(:client) do
    described_class.new(base_url: base_url, username: "office-service", password: password)
  end

  def expect_error(error_code)
    yield
  rescue DiscourseNextcloudOffice::NextcloudError => error
    expect(error.error_code).to eq(error_code)
    error
  else
    raise "expected NextcloudError #{error_code}"
  end

  describe "same-origin requests" do
    it "sends Basic auth to a relative path" do
      stub =
        stub_request(:get, "https://cloud.example.com/ocs/v2.php/cloud/capabilities").with(
          headers: {
            "Authorization" => "Basic #{["office-service:#{password}"].pack("m0")}",
          },
        ).to_return(
          status: 200,
          body: '{"ok":true}',
          headers: {
            "Content-Type" => "application/json",
          },
        )

      response = client.get("/ocs/v2.php/cloud/capabilities")

      expect(stub).to have_been_requested.once
      expect(response.status).to eq(200)
      expect(response.body).to eq('{"ok":true}')
      expect(response).to be_success
      expect(response.header("content-type")).to eq("application/json")
    end

    it "rejects absolute URLs even on the configured origin" do
      expect_error("invalid_request_path") { client.get("https://cloud.example.com/status.php") }
    end

    it "adds query parameters and keeps them encoded" do
      stub =
        stub_request(
          :get,
          "https://cloud.example.com/ocs/v2.php/apps/files_sharing/api/v1/shares",
        ).with(query: { "path" => "/Discourse/Plan.docx" }).to_return(status: 200, body: "{}")

      client.get(
        "/ocs/v2.php/apps/files_sharing/api/v1/shares",
        query: {
          "path" => "/Discourse/Plan.docx",
        },
      )

      expect(stub).to have_been_requested.once
    end

    it "returns a redirect as an error instead of following it" do
      stub_request(:get, "https://cloud.example.com/ocs/v2.php").to_return(
        status: 302,
        headers: {
          "Location" => "https://attacker.example/collect",
        },
      )
      attacker = stub_request(:get, "https://attacker.example/collect")

      expect_error("nextcloud_redirect_refused") { client.get("/ocs/v2.php") }

      expect(attacker).not_to have_been_requested
    end
  end

  describe "origin and parameter guards" do
    it "refuses a foreign host before any request" do
      foreign = stub_request(:get, "https://other.example/ocs")

      expect_error("invalid_request_path") { client.get("https://other.example/ocs") }
      expect_error("invalid_request_path") { client.get("http://cloud.example.com/ocs") }
      expect_error("invalid_request_path") { client.get("https://cloud.example.com:8443/ocs") }

      expect(foreign).not_to have_been_requested
      expect(a_request(:any, /cloud\.example\.com/)).not_to have_been_made
    end

    it "refuses credential-bearing and backslash paths" do
      expect_error("invalid_request_path") { client.get("https://user:pass@cloud.example.com/ocs") }
      expect_error("invalid_request_path") { client.get("/ocs\\..\\share") }
      expect(a_request(:any, /cloud\.example\.com/)).not_to have_been_made
    end

    it "rejects embedded queries and protocol-relative paths" do
      expect_error("invalid_request_path") do
        client.get("/ocs/v2.php/share?downloadUrl=https%3A%2F%2Fattacker.example%2Fx")
      end
      expect_error("invalid_request_path") { client.get("//attacker.example/x") }

      expect(a_request(:any, /cloud\.example\.com/)).not_to have_been_made
    end
  end

  describe "transport failures" do
    it "bounds the whole request even when the peer keeps sending chunks" do
      limited =
        described_class.new(
          base_url: base_url,
          username: "office-service",
          password: password,
          request_timeout: 0.02,
        )
      stub_request(:get, "https://cloud.example.com/trickle").to_return do
        sleep 0.2
        { status: 200, body: "late" }
      end

      expect_error("nextcloud_timeout") { limited.get("/trickle") }
    end

    it "requires explicit Core allowlisting for private destinations" do
      detector = FinalDestination::SSRFDetector
      allow(FinalDestination::Resolver).to receive(:lookup).and_return(["192.168.1.42"])
      detector.allow_ip_lookups_in_test!
      stub = stub_request(:get, "https://cloud.example.com/status.php").to_return(body: "ok")

      expect_error("nextcloud_private_address_refused") { client.get("/status.php") }
      expect(stub).not_to have_been_requested

      SiteSetting.allowed_internal_hosts = "cloud.example.com"
      expect(client.get("/status.php").body).to eq("ok")
    ensure
      detector.disallow_ip_lookups_in_test!
    end

    it "limits response bodies" do
      limited =
        described_class.new(
          base_url: base_url,
          username: "office-service",
          password: password,
          max_response_bytes: 1_024,
        )
      stub_request(:get, "https://cloud.example.com/big").to_return(status: 200, body: "x" * 2_048)

      expect_error("nextcloud_response_too_large") { limited.get("/big") }
    end

    it "maps read and open timeouts" do
      stub_request(:get, "https://cloud.example.com/slow").to_raise(Net::ReadTimeout.new("boom"))
      stub_request(:get, "https://cloud.example.com/connect").to_raise(Net::OpenTimeout.new("boom"))

      expect_error("nextcloud_timeout") { client.get("/slow") }
      expect_error("nextcloud_timeout") { client.get("/connect") }
    end

    it "maps TLS verification failures" do
      stub_request(:get, "https://cloud.example.com/ocs").to_raise(
        OpenSSL::SSL::SSLError.new("certificate verify failed"),
      )

      expect_error("nextcloud_tls_error") { client.get("/ocs") }
    end

    it "maps connection failures" do
      stub_request(:get, "https://cloud.example.com/refused").to_raise(Errno::ECONNREFUSED.new)
      stub_request(:get, "https://cloud.example.com/dns").to_raise(SocketError.new("getaddrinfo"))

      expect_error("nextcloud_unavailable") { client.get("/refused") }
      expect_error("nextcloud_unavailable") { client.get("/dns") }
    end
  end

  describe ".from_configuration" do
    before do
      SiteSetting.nextcloud_office_enabled = true
      SiteSetting.nextcloud_office_base_url = base_url
      SiteSetting.nextcloud_office_username = "office-service"
      SiteSetting.nextcloud_office_app_password = password
    end

    it "builds a client for a ready configuration" do
      stub_request(:get, "https://cloud.example.com/status.php").to_return(status: 200, body: "ok")

      built = described_class.from_configuration(DiscourseNextcloudOffice::Configuration.current)

      expect(built.get("/status.php").body).to eq("ok")
    end

    it "refuses an incomplete configuration" do
      SiteSetting.nextcloud_office_app_password = ""

      expect_error("not_configured") do
        described_class.from_configuration(DiscourseNextcloudOffice::Configuration.current)
      end
    end
  end

  it "never prints the app password" do
    expect(client.inspect).to include("[FILTERED]")
    expect(client.inspect).not_to include(password)
  end
end
