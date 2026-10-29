# frozen_string_literal: true

RSpec.describe DiscourseNextcloudOffice do
  let(:canary_password) { "canary-app-password-9f2a" }

  describe "site settings" do
    it "exposes only the enabled flag to clients" do
      exposed = SiteSetting.client_settings.map(&:to_s)

      expect(exposed).to include("nextcloud_office_enabled")
      expect(exposed).not_to include(
        "nextcloud_office_app_password",
        "nextcloud_office_base_url",
        "nextcloud_office_username",
        "nextcloud_office_folder",
        "nextcloud_office_max_file_size_mb",
      )
    end

    it "keeps the app password out of the client settings JSON" do
      SiteSetting.nextcloud_office_app_password = canary_password
      SiteSetting.nextcloud_office_username = "canary-service-account"

      json = SiteSetting.client_settings_json

      expect(json).not_to include(canary_password)
      expect(json).not_to include("canary-service-account")
    end

    it "marks the app password as a secret setting" do
      expect(SiteSetting.secret_settings).to include(:nextcloud_office_app_password)
    end
  end

  describe "parameter filtering" do
    let(:filter) do
      ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    end

    it "filters Office credentials in logged parameters" do
      filtered =
        filter.filter(
          "share_password" => "share-canary-value",
          "nextcloud_office_app_password" => canary_password,
          "file_name" => "Plan.docx",
        )

      expect(filtered["share_password"]).to eq("[FILTERED]")
      expect(filtered["nextcloud_office_app_password"]).to eq("[FILTERED]")
      expect(filtered["file_name"]).to eq("Plan.docx")
    end

    it "filters nested and array-shaped values" do
      filtered =
        filter.filter(
          "nextcloud_office" => {
            "items" => [{ "share_password" => "nested-canary" }],
          },
          "share_password" => ["first-canary", "second-canary"],
        )

      expect(filtered.to_s).not_to include("canary")
    end
  end

  describe "error objects" do
    it "carries only the error code in the exception message" do
      error = DiscourseNextcloudOffice::RequestError.new(:not_configured, status: :service_unavailable)

      expect(error.message).to eq("not_configured")
      expect(error.inspect).not_to include(canary_password)
    end

    it "exposes no secret in the configuration summary" do
      SiteSetting.nextcloud_office_enabled = true
      configuration =
        DiscourseNextcloudOffice::Configuration.new(
          base_url: "https://cloud.example.com",
          username: "office-service",
          app_password: canary_password,
          folder: "Community",
        )

      expect(configuration.to_h.to_s).not_to include(canary_password)
      expect(configuration.inspect).not_to include(canary_password)
      expect(configuration.inspect).to include("[FILTERED]")
    end
  end
end
