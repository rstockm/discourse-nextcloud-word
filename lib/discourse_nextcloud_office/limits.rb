# frozen_string_literal: true

module ::DiscourseNextcloudOffice
  # Transport and policy limits for office requests.
  #
  # The effective file cap never exceeds the site's own attachment limit, so the
  # endpoint cannot be used to publish files the upload policy would reject.
  module Limits
    MULTIPART_OVERHEAD_BYTES = 64 * 1024
    JSON_BODY_BYTES = 16 * 1024
    MAX_FILE_MB_CAP = 100

    module_function

    def max_file_bytes
      [configured_megabytes.megabytes, SiteSetting.max_attachment_size_kb.to_i.kilobytes].min
    end

    def max_body_bytes(multipart:)
      multipart ? max_file_bytes + MULTIPART_OVERHEAD_BYTES : JSON_BODY_BYTES
    end

    # Content-Length is client supplied: this rejects obvious oversized bodies
    # early, while assert_file_size! checks the bytes that actually arrived.
    def assert_body_size!(content_length, multipart:)
      return if content_length.blank?
      return if content_length.to_i <= max_body_bytes(multipart: multipart)

      raise ::DiscourseNextcloudOffice::RequestError.new(:request_too_large, status: :payload_too_large)
    end

    def assert_office_file_size!(file)
      size = file.tempfile.size
      return if size <= max_file_bytes

      raise ::DiscourseNextcloudOffice::RequestError.new(:file_too_large, status: :payload_too_large)
    end

    def assert_upload_allowed!(format, user:)
      return if upload_extension_allowed?(format, user: user)

      raise ::DiscourseNextcloudOffice::RequestError.new(
              :file_type_not_allowed,
              status: :unsupported_media_type,
            )
    end

    def upload_extension_allowed?(format, user:)
      extensions = allowed_extensions(user: user)
      extensions.include?("*") || extensions.include?(format.to_s.downcase)
    end

    def allowed_extensions(user:)
      raw = SiteSetting.authorized_extensions.to_s
      raw = "#{raw}|#{SiteSetting.authorized_extensions_for_staff}" if user&.staff?
      parse_extensions(raw)
    end

    def parse_extensions(raw)
      raw.gsub(/[\s.]+/, "").downcase.split("|").reject(&:blank?).to_set
    end

    def configured_megabytes
      SiteSetting.nextcloud_office_max_file_size_mb.to_i.clamp(1, MAX_FILE_MB_CAP)
    end
  end
end
