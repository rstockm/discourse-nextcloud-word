# frozen_string_literal: true

RSpec.describe DiscourseNextcloudOffice::Configuration do
  before { SiteSetting.nextcloud_office_enabled = true }

  def configuration(overrides = {})
    described_class.new(
      **{
        base_url: "https://cloud.example.com",
        username: "office-service",
        app_password: "synthetic-app-password",
        folder: "Community/Discourse",
      }.merge(overrides),
    )
  end

  describe "#status" do
    it "is ready for a complete HTTPS configuration" do
      expect(configuration.status).to eq(:ready)
      expect(configuration).to be_ready
    end

    it "is disabled while the plugin setting is off" do
      SiteSetting.nextcloud_office_enabled = false

      expect(configuration.status).to eq(:disabled)
    end

    it "is unconfigured when any required value is missing" do
      expect(configuration(base_url: "").status).to eq(:unconfigured)
      expect(configuration(username: "").status).to eq(:unconfigured)
      expect(configuration(app_password: "").status).to eq(:unconfigured)
    end
  end

  describe "base URL" do
    it "normalizes an HTTPS origin without a trailing slash" do
      expect(configuration(base_url: "https://CLOUD.example.com/").base_url).to eq(
        "https://cloud.example.com",
      )
    end

    it "keeps a non-default explicit port" do
      expect(configuration(base_url: "https://cloud.example.com:8443").base_url).to eq(
        "https://cloud.example.com:8443",
      )
    end

    it "rejects non-HTTPS, paths, queries, credentials and malformed values" do
      values = [
        "http://cloud.example.com",
        "https://cloud.example.com/nextcloud",
        "https://cloud.example.com?token=1",
        "https://cloud.example.com#fragment",
        "https://user:pass@cloud.example.com",
        "cloud.example.com",
        "https://cloud example.com",
      ]

      values.each do |value|
        result = configuration(base_url: value)
        expect(result.status).to eq(:unconfigured), "expected #{value.inspect} to be rejected"
        expect(result.problems).to include(:base_url_invalid)
      end
    end
  end

  describe "credentials" do
    it "rejects blank, padded or slash-containing usernames" do
      ["", "  ", " office-service", "office/service", "office\\service"].each do |value|
        problems = configuration(username: value).problems
        expect(problems & %i[username_missing username_invalid]).not_to be_empty
      end
    end

    it "rejects blank and padded app passwords" do
      expect(configuration(app_password: "").problems).to include(:app_password_missing)
      expect(configuration(app_password: "secret ").problems).to include(:app_password_invalid)
    end

    it "never exposes the app password in inspect output" do
      expect(configuration.inspect).not_to include("synthetic-app-password")
      expect(configuration.to_h).not_to have_key(:app_password)
    end
  end

  describe "folder" do
    it "accepts nested relative folders and treats blank as the account root" do
      expect(configuration(folder: "Community/Discourse").folder).to eq("Community/Discourse")
      expect(configuration(folder: " ").folder).to eq("")
    end

    it "rejects absolute, traversal and backslash paths" do
      ["/Community", "Community/../Secrets", "Community//Discourse", "Community\\Discourse", "."].each do |value|
        expect(configuration(folder: value).problems).to include(:folder_invalid)
      end
    end
  end
end
