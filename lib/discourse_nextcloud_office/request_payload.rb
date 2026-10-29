# frozen_string_literal: true

module ::DiscourseNextcloudOffice
  # Shared strict parameter reading. Only scalar strings are accepted; arrays
  # and nested objects are rejected instead of being coerced by Rails.
  class RequestPayload
    OPERATION_KEY_PATTERN = /\A[A-Za-z0-9_-]{1,128}\z/
    MAX_SHARE_PASSWORD_BYTES = 256

    def initialize(params)
      @params = params
      allowed = %w[file file_name file_type operation_key share_password controller action format]
      raise invalid_parameters if (params.keys.map(&:to_s) - allowed).any?
    end

    private

    def invalid_parameters
      ::DiscourseNextcloudOffice::RequestError.new(:invalid_parameters, status: :bad_request)
    end

    def invalid_operation_key
      ::DiscourseNextcloudOffice::RequestError.new(:invalid_operation_key, status: :bad_request)
    end

    def invalid_share_password
      ::DiscourseNextcloudOffice::RequestError.new(:invalid_share_password, status: :bad_request)
    end

    def param_string(key, required: true)
      value = @params[key]
      if value.nil?
        raise invalid_parameters if required
        return nil
      end
      raise invalid_parameters if !value.is_a?(String) || !value.valid_encoding?

      value
    end

    def parse_file_type(allow:)
      value = param_string(:file_type)
      raise invalid_parameters if value != value.strip

      normalized = ::DiscourseNextcloudOffice::OfficeFormat.normalize(value)
      if normalized.nil? || !allow.include?(normalized)
        raise ::DiscourseNextcloudOffice::RequestError.new(
                :unsupported_file_type,
                status: :unsupported_media_type,
              )
      end

      normalized
    end

    def parse_operation_key
      value = param_string(:operation_key)
      raise invalid_operation_key if !value.match?(OPERATION_KEY_PATTERN)

      value
    end

    def parse_share_password
      value = param_string(:share_password, required: false)
      return nil if value.nil? || value.empty?

      invalid =
        value.bytesize > MAX_SHARE_PASSWORD_BYTES || value != value.strip ||
          value.match?(/[[:cntrl:]]/)
      raise invalid_share_password if invalid

      value
    end
  end
end
