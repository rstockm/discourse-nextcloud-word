# frozen_string_literal: true

require "uri"

module ::DiscourseNextcloudOffice
  # Validated view of the administrator-provided Nextcloud connection settings.
  #
  # The class never talks to Nextcloud. It only decides whether the stored
  # values are complete and safe enough to be used by the request layer.
  class Configuration
    MAX_BASE_URL_LENGTH = 2_048
    MAX_USERNAME_LENGTH = 255
    MAX_APP_PASSWORD_LENGTH = 4_096
    MAX_FOLDER_LENGTH = 512
    MAX_FOLDER_SEGMENT_LENGTH = 255

    attr_reader :base_url, :username, :app_password, :folder, :problems

    def self.current
      new(
        base_url: SiteSetting.nextcloud_office_base_url,
        username: SiteSetting.nextcloud_office_username,
        app_password: SiteSetting.nextcloud_office_app_password,
        folder: SiteSetting.nextcloud_office_folder,
      )
    end

    def initialize(base_url:, username:, app_password:, folder:)
      @problems = []
      @base_url = normalize_base_url(base_url)
      @username = normalize_username(username)
      @app_password = normalize_app_password(app_password)
      @folder = normalize_folder(folder)
    end

    def status
      return :disabled if !SiteSetting.nextcloud_office_enabled
      return :unconfigured if problems.any?

      :ready
    end

    def ready?
      status == :ready
    end

    # Safe summary for diagnostics. Never contains the app password.
    def to_h
      { status: status, base_url: base_url, username: username, folder: folder }
    end

    def inspect
      "#<#{self.class.name} status=#{status.inspect} base_url=#{base_url.inspect} " \
        "username=#{username.inspect} folder=#{folder.inspect} app_password=[FILTERED]>"
    end

    private

    def problem(code)
      @problems << code
      nil
    end

    def normalize_base_url(value)
      raw = value.to_s.strip
      return problem(:base_url_missing) if raw.empty?
      return problem(:base_url_invalid) if invalid_base_url_text?(raw)

      uri = URI.parse(raw)
      return problem(:base_url_invalid) if !valid_base_uri?(uri)

      port = uri.port == uri.default_port ? "" : ":#{uri.port}"
      "#{uri.scheme}://#{uri.host.downcase}#{port}"
    rescue URI::InvalidURIError
      problem(:base_url_invalid)
    end

    def invalid_base_url_text?(raw)
      raw.length > MAX_BASE_URL_LENGTH || raw.match?(/[[:space:][:cntrl:]]/)
    end

    def valid_base_uri?(uri)
      uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.nil? && uri.query.nil? &&
        uri.fragment.nil? && (uri.path.empty? || uri.path == "/")
    end

    def normalize_username(value)
      raw = value.to_s
      stripped = raw.strip
      return problem(:username_missing) if stripped.empty?

      invalid =
        stripped.length > MAX_USERNAME_LENGTH || stripped != raw ||
          stripped.match?(%r{[/\\]}) || stripped.match?(/[[:cntrl:]]/)
      return problem(:username_invalid) if invalid

      stripped
    end

    def normalize_app_password(value)
      raw = value.to_s
      return problem(:app_password_missing) if raw.empty?

      invalid =
        raw.length > MAX_APP_PASSWORD_LENGTH || raw != raw.strip ||
          raw.match?(/[[:cntrl:]]/)
      return problem(:app_password_invalid) if invalid

      raw
    end

    def normalize_folder(value)
      raw = value.to_s.strip
      return "" if raw.empty?

      segments = raw.split("/", -1)
      invalid =
        raw.length > MAX_FOLDER_LENGTH || raw.start_with?("/") || raw.include?("\\") ||
          segments.any? do |segment|
            segment.empty? || segment == "." || segment == ".." ||
              segment.length > MAX_FOLDER_SEGMENT_LENGTH || segment != segment.strip ||
              segment.match?(/[[:cntrl:]]/)
          end
      return problem(:folder_invalid) if invalid

      raw
    end
  end
end
