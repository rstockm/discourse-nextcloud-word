# frozen_string_literal: true

module ::DiscourseNextcloudOffice
  # Supported upload and template formats. The list is intentionally closed:
  # the client cannot opt into additional extensions or MIME types.
  module OfficeFormat
    MIME_TYPES = {
      "docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      "xlsx" => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      "pptx" => "application/vnd.openxmlformats-officedocument.presentationml.presentation",
      "odt" => "application/vnd.oasis.opendocument.text",
      "ods" => "application/vnd.oasis.opendocument.spreadsheet",
      "odp" => "application/vnd.oasis.opendocument.presentation",
    }.freeze

    UPLOAD_FORMATS = MIME_TYPES.keys.freeze
    TEMPLATE_FORMATS = %w[docx xlsx pptx].freeze

    module_function

    def normalize(value)
      return nil if !value.is_a?(String)

      normalized = value.downcase
      MIME_TYPES.key?(normalized) ? normalized : nil
    end

    def supported?(value)
      !normalize(value).nil?
    end

    def template?(value)
      TEMPLATE_FORMATS.include?(normalize(value))
    end

    def upload?(value)
      UPLOAD_FORMATS.include?(normalize(value))
    end

    def mime_type(value)
      MIME_TYPES[normalize(value)]
    end
  end
end
