# frozen_string_literal: true

module ::DiscourseNextcloudOffice
  # Normalizes a user-supplied display name into one safe file name.
  #
  # The output keeps Unicode text, removes path/control/formatting characters
  # and applies exactly one extension matching the validated format.
  class FileName
    MAX_BYTES = 200
    DEFAULT = "Document"

    INVALID_CHARACTERS = /[<>:"\/\\|?*]/
    CONTROL_AND_DIRECTIONAL = /[[:cntrl:]\u200B\u200E\u200F\u202A-\u202E\u2066-\u2069\uFEFF]/

    def self.normalize(value, format:)
      new(value, format: format).normalize
    end

    def initialize(value, format:)
      @value = value
      @format = format
    end

    def normalize
      raise invalid_name if !@value.is_a?(String)

      name = @value.dup.force_encoding(Encoding::UTF_8)
      raise invalid_name if !name.valid_encoding?

      name = name.unicode_normalize(:nfc)
      name = name.gsub(CONTROL_AND_DIRECTIONAL, "").gsub(INVALID_CHARACTERS, "")
      name = name.gsub(/\s+/, " ").strip
      name = name.sub(/\A\.+/, "").sub(/\.+\z/, "")
      name = remove_matching_extensions(name)
      raise extension_mismatch if contains_foreign_office_extension?(name)

      name = truncate(name, MAX_BYTES - @format.bytesize - 1)
      name = DEFAULT if name.empty?

      "#{name}.#{@format}"
    end

    private

    def invalid_name
      ::DiscourseNextcloudOffice::RequestError.new(:invalid_file_name, status: :bad_request)
    end

    def extension_mismatch
      ::DiscourseNextcloudOffice::RequestError.new(:file_extension_mismatch, status: :bad_request)
    end

    def remove_matching_extensions(name)
      name.sub(/(?:\.#{Regexp.escape(@format)})+\z/i, "")
    end

    def contains_foreign_office_extension?(name)
      name
        .split(".")
        .drop(1)
        .any? { |segment| ::DiscourseNextcloudOffice::OfficeFormat.supported?(segment) }
    end

    # Cuts on a UTF-8 character boundary and never leaves a trailing dot/space.
    def truncate(name, max_bytes)
      return name if name.bytesize <= max_bytes

      truncated = name.byteslice(0, max_bytes).to_s.scrub("")
      truncated.sub(/[. ]+\z/, "")
    end
  end
end
