# frozen_string_literal: true

module ::DiscourseNextcloudOffice
  # Internal transport failure. Only the safe code ever reaches the browser.
  #
  # The message is a fixed code as well, so exception logging cannot leak
  # upstream bodies, URLs with credentials or TLS details by accident.
  class NextcloudError < StandardError
    attr_reader :error_code, :status

    def initialize(error_code, status: nil)
      @error_code = error_code.to_s
      @status = status
      super(@error_code)
    end
  end
end
