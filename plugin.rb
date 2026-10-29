# frozen_string_literal: true

# name: discourse-nextcloud-office
# about: Create and transfer Office documents from the composer to Nextcloud.
# version: 0.1.0
# authors: Ralf Stockmann
# url: https://github.com/rstockm/discourse-nextcloud-word
# required_version: 2026.11.0-latest

enabled_site_setting :nextcloud_office_enabled

# Never let request/parameter logging capture Office credentials or share
# passwords, even if a future parameter name does not match Rails' defaults.
Rails.application.config.filter_parameters += %i[
  nextcloud_office_app_password
  share_password
]

module ::DiscourseNextcloudOffice
  PLUGIN_NAME = "discourse-nextcloud-office"
end

require_relative "lib/discourse_nextcloud_office/engine"
