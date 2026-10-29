# frozen_string_literal: true

require "json"
require "uri"

module ::DiscourseNextcloudOffice
  class Shares
    ENDPOINT = "/ocs/v2.php/apps/files_sharing/api/v1/shares"
    HEADERS = { "OCS-APIRequest" => "true", "Accept" => "application/json" }.freeze

    def initialize(configuration, client: NextcloudClient.from_configuration(configuration))
      @client = client
      @owner = configuration.username
      @origin = URI(configuration.base_url)
    end

    def create!(path, password: nil)
      fields = { path: path, shareType: 3, permissions: 3 }
      fields[:password] = password if password.present?
      response =
        @client.post(
          ENDPOINT,
          query: {
            format: "json",
          },
          body: URI.encode_www_form(fields),
          headers: HEADERS.merge("Content-Type" => "application/x-www-form-urlencoded"),
        )
      data = parse_response(response)
      validate_share!(data, path: path, password_required: password.present?)
    end

    # Used by recovery before any repeated share creation, never auto-deletes.
    def find(path, password_required:)
      response =
        @client.get(
          ENDPOINT,
          query: {
            format: "json",
            path: path,
            reshares: "false",
            subfiles: "false",
          },
          headers: HEADERS,
        )
      data = parse_response(response)
      raise NextcloudError.new(:invalid_share_response) if !data.is_a?(Array)

      candidates =
        data.select do |share|
          share.is_a?(Hash) && share["path"] == path && share["uid_owner"] == @owner &&
            share["share_type"].to_s == "3"
        end
      return nil if candidates.empty?
      raise NextcloudError.new(:ambiguous_share) if candidates.length != 1

      validate_share!(candidates.first, path: path, password_required: password_required)
    end

    private

    def parse_response(response)
      raise NextcloudError.new(:share_request_failed) if !response.success?

      envelope = JSON.parse(response.body)
      meta = envelope.dig("ocs", "meta")
      unless meta.is_a?(Hash) && meta["status"] == "ok" &&
               %w[100 200].include?(meta["statuscode"].to_s)
        raise NextcloudError.new(:share_request_failed)
      end
      envelope.fetch("ocs").fetch("data")
    rescue JSON::ParserError, KeyError, TypeError, NoMethodError
      raise NextcloudError.new(:invalid_share_response), cause: nil
    end

    def validate_share!(share, path:, password_required:)
      unless share.is_a?(Hash) && share["id"].to_s.match?(/\A[1-9][0-9]*\z/) &&
               share["path"] == path && share["uid_owner"] == @owner &&
               share["item_type"] == "file" && share["share_type"].to_s == "3" &&
               share["permissions"].to_s == "3"
        raise NextcloudError.new(:invalid_share_response)
      end

      # Nextcloud returns null or 'redacted', not the password or its hash.
      has_password = share["password"] == "redacted"
      unless share.key?("password") && [nil, "redacted"].include?(share["password"]) &&
               has_password == password_required
        raise NextcloudError.new(:share_password_mismatch)
      end
      validate_url!(share["url"], share["token"])
      { id: share["id"].to_s, url: share["url"], has_password: has_password }
    end

    def validate_url!(url, token)
      unless url.is_a?(String) && token.is_a?(String) && token.match?(/\A[A-Za-z0-9-]{1,32}\z/)
        raise NextcloudError.new(:invalid_share_url)
      end
      uri = URI.parse(url)
      valid =
        uri.is_a?(URI::HTTPS) && uri.hostname&.casecmp?(@origin.hostname) &&
          uri.port == @origin.port && uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil? &&
          ["/s/#{token}", "/index.php/s/#{token}"].include?(uri.path)
      raise NextcloudError.new(:invalid_share_url) if !valid
    rescue URI::InvalidURIError
      raise NextcloudError.new(:invalid_share_url), cause: nil
    end
  end
end
