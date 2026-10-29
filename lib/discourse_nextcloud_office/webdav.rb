# frozen_string_literal: true

require "uri"

module ::DiscourseNextcloudOffice
  class Webdav
    def initialize(configuration, client: NextcloudClient.from_configuration(configuration))
      @client = client
      @folder = configuration.folder
      @root = "/remote.php/dav/files/#{encode(configuration.username)}"
    end

    # Persist this path once in the operation before making any remote mutation.
    def allocate_path(file_name)
      check_segment!(file_name)
      "/#{[@folder.presence, "#{SecureRandom.uuid}-#{file_name}"].compact.join("/")}"
    end

    def create!(path, source:, file_type:)
      response =
        @client.put(
          remote_path(path),
          body: source,
          headers: {
            "If-None-Match" => "*",
            "Content-Type" => OfficeFormat.mime_type(file_type),
          },
        )
      raise NextcloudError.new(:file_conflict) if response.status == 412
      # 204 means an overwrite, not a successful creation. Never retry it.
      if response.status == 204 || response.status >= 500
        raise NextcloudError.new(:file_outcome_unknown)
      end
      raise NextcloudError.new(:file_creation_failed) if response.status != 201

      { path: path, etag: response.header("etag") || response.header("oc-etag") }
    rescue NextcloudError => error
      if %w[nextcloud_timeout nextcloud_unavailable nextcloud_response_too_large].include?(
           error.error_code,
         )
        raise NextcloudError.new(:file_outcome_unknown), cause: nil
      end
      raise
    end

    def stat(path)
      response = @client.head(remote_path(path))
      return nil if response.status == 404
      raise NextcloudError.new(:file_lookup_failed) if response.status != 200

      { etag: response.header("etag"), size: response.header("content-length")&.to_i }
    end

    def checksum(path)
      @client.checksum(remote_path(path), max_bytes: Limits.max_file_bytes)
    end

    private

    def remote_path(path)
      prefix = @folder.empty? ? "/" : "/#{@folder}/"
      if !path.is_a?(String) || !path.start_with?(prefix)
        raise NextcloudError.new(:invalid_request_path)
      end

      segments = path.delete_prefix("/").split("/", -1)
      segments.each { |segment| check_segment!(segment) }
      "#{@root}/#{segments.map { |segment| encode(segment) }.join("/")}"
    end

    def check_segment!(value)
      unless value.is_a?(String) && value.valid_encoding? && value.present? &&
               !%w[. ..].include?(value) && !value.match?(%r{[/\\\x00-\x1f\x7f]})
        raise NextcloudError.new(:invalid_request_path)
      end
    end

    def encode(value)
      URI.encode_www_form_component(value).gsub("+", "%20")
    end
  end
end
