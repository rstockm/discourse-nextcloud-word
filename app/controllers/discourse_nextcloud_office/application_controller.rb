# frozen_string_literal: true

module ::DiscourseNextcloudOffice
  # Shared request boundary for every Nextcloud Office endpoint.
  #
  # Guard order is deliberate: plugin state, session (never API keys), account
  # state and configuration are checked before any action can touch Nextcloud.
  class ApplicationController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    CORRELATION_ID_HEADER = "X-Discourse-Office-Correlation-Id"
    CORRELATION_ID_ENV_KEY = "discourse_nextcloud_office.correlation_id"

    before_action :set_office_correlation_id
    before_action :reject_api_authentication
    before_action :ensure_office_user
    before_action :ensure_office_configured

    rescue_from ::DiscourseNextcloudOffice::RequestError, with: :render_office_error_response

    def handle_unverified_request
      # Core lets API-key requests bypass CSRF. Office endpoints never accept
      # API keys, so the request is rejected by reject_api_authentication below.
      return if is_api? || is_user_api?

      clear_current_user
      render_office_error(error_code: :csrf_failed, status: :forbidden)
    end

    private

    def configuration
      @configuration ||= ::DiscourseNextcloudOffice::Configuration.current
    end

    def office_correlation_id
      @office_correlation_id ||= request.env[CORRELATION_ID_ENV_KEY] ||= SecureRandom.uuid
    end

    def set_office_correlation_id
      response.headers[CORRELATION_ID_HEADER] = office_correlation_id
      response.headers["Cache-Control"] = "no-store"
    end

    def reject_api_authentication
      return if !(is_api? || is_user_api?)

      raise ::DiscourseNextcloudOffice::RequestError.new(:session_required, status: :forbidden)
    end

    def ensure_office_user
      if current_user.blank?
        raise ::DiscourseNextcloudOffice::RequestError.new(:not_logged_in, status: :forbidden)
      end
      return if current_user.active? && !current_user.suspended?

      raise ::DiscourseNextcloudOffice::RequestError.new(:account_inactive, status: :forbidden)
    end

    def ensure_office_configured
      return if configuration.ready?

      raise ::DiscourseNextcloudOffice::RequestError.new(
              :not_configured,
              status: :service_unavailable,
            )
    end

    def render_office_error_response(error)
      render_office_error(
        error_code: error.error_code,
        status: error.status,
        message_key: error.message_key,
        retry_after: error.retry_after,
      )
    end

    def render_office_error(error_code:, status:, message_key: nil, retry_after: nil)
      set_office_correlation_id
      response.headers["Cache-Control"] = "no-store"
      response.headers["Retry-After"] = retry_after.to_i.to_s if retry_after

      render(
        json: {
          success: false,
          error_code: error_code.to_s,
          error:
            I18n.t(
              "nextcloud_office.errors.#{message_key || error_code}",
              default: I18n.t("nextcloud_office.errors.generic"),
            ),
          correlation_id: office_correlation_id,
        },
        status: status,
      )
    end
  end
end
