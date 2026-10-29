# frozen_string_literal: true

RSpec.describe DiscourseNextcloudOffice do
  let(:plugin) { Discourse.plugins_by_name["discourse-nextcloud-office"] }

  it "is registered with the pinned engine and defaults to disabled" do
    expect(plugin).to be_present
    expect(plugin.enabled_site_setting).to eq(:nextcloud_office_enabled)
    expect(plugin.enabled?).to eq(false)
  end

  it "starts disabled until an administrator enables the integration" do
    expect(SiteSetting.nextcloud_office_enabled).to eq(false)
  end

  it "can be disabled again without changing existing uploads" do
    upload = Fabricate(:upload)
    SiteSetting.nextcloud_office_enabled = true

    SiteSetting.nextcloud_office_enabled = false

    expect(plugin.enabled?).to eq(false)
    expect(Upload.exists?(upload.id)).to eq(true)
  end
end
