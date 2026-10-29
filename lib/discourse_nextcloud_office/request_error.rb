# frozen_string_literal: true

module ::DiscourseNextcloudOffice
  # A request failure that is safe to show to the client.
  #
  # The controller translates the message key through the plugin locale files.
  # Upstream response bodies and exception messages must never be attached.
  class RequestError < StandardError
    attr_reader :error_code, :status, :message_key, :retry_after

    def initialize(error_code, status:, message_key: nil, retry_after: nil)
      @error_code = error_code.to_s
      @status = status
      @message_key = (message_key || error_code).to_s
      @retry_after = retry_after
      super(@error_code)
    end
  end
end
