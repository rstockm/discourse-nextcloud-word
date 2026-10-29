# frozen_string_literal: true

require "digest"
require "net/http"
require "openssl"
require "uri"
require "timeout"

module ::DiscourseNextcloudOffice
  # Minimal, bounded HTTP transport for the administrator-configured Nextcloud.
  #
  # It owns no WebDAV/OCS semantics (tasks 3.2/3.3 build on it). Its job is to
  # make every call same-origin, TLS-verified, redirect-free and size-limited.
  class NextcloudClient
    OPEN_TIMEOUT_SECONDS = 5
    READ_TIMEOUT_SECONDS = 30
    WRITE_TIMEOUT_SECONDS = 30
    MAX_RESPONSE_BYTES = 1 * 1024 * 1024
    MINIMUM_TLS_VERSION = OpenSSL::SSL::TLS1_2_VERSION
    REQUEST_TIMEOUT_SECONDS = 30

    Response =
      Struct.new(:status, :headers, :body, keyword_init: true) do
        def success?
          status.to_i.between?(200, 299)
        end

        def redirect?
          status.to_i.between?(300, 399)
        end

        def header(name)
          headers&.fetch(name.to_s.downcase, nil)
        end
      end

    attr_reader :base_uri

    def self.from_configuration(configuration)
      raise NextcloudError.new(:not_configured) if !configuration.ready?

      new(
        base_url: configuration.base_url,
        username: configuration.username,
        password: configuration.app_password,
      )
    end

    def initialize(
      base_url:,
      username:,
      password:,
      open_timeout: OPEN_TIMEOUT_SECONDS,
      read_timeout: READ_TIMEOUT_SECONDS,
      max_response_bytes: MAX_RESPONSE_BYTES,
      request_timeout: REQUEST_TIMEOUT_SECONDS
    )
      @base_uri = parse_base_uri(base_url)
      @username = username.to_s
      @password = password.to_s
      @open_timeout = open_timeout
      @read_timeout = read_timeout
      @max_response_bytes = max_response_bytes
      @request_timeout = request_timeout
    end

    def get(path, query: {}, headers: {})
      perform(Net::HTTP::Get, path, query: query, headers: headers)
    end

    def head(path)
      perform(Net::HTTP::Head, path)
    end

    # Recovery proof without buffering a potentially large Office document.
    def checksum(path, max_bytes:)
      uri = resolved_uri(path)
      transmit(uri, build_request(Net::HTTP::Get, uri, {})) do |raw|
        next nil if raw.code.to_i == 404
        raise NextcloudError.new(:file_lookup_failed) if raw.code.to_i != 200

        digest = Digest::SHA256.new
        bytes = 0
        raw.read_body do |chunk|
          bytes += chunk.bytesize
          raise NextcloudError.new(:file_lookup_failed) if bytes > max_bytes
          digest.update(chunk)
        end
        { digest: digest.hexdigest, etag: raw["etag"] }
      end
    end

    def post(path, body: nil, query: {}, headers: {})
      perform(Net::HTTP::Post, path, body: body, query: query, headers: headers)
    end

    def put(path, body: nil, query: {}, headers: {})
      perform(Net::HTTP::Put, path, body: body, query: query, headers: headers)
    end

    def delete(path, query: {}, headers: {})
      perform(Net::HTTP::Delete, path, query: query, headers: headers)
    end

    # Absolute URL of a same-origin endpoint; used to build WebDAV/OCS targets.
    def url_for(path, query: {})
      uri = resolved_uri(path, query: query)
      uri.to_s
    end

    def inspect
      "#<#{self.class.name} base_uri=#{base_uri} password=[FILTERED]>"
    end

    private

    def parse_base_uri(base_url)
      uri = URI.parse(base_url.to_s)
      raise NextcloudError.new(:not_configured) if !uri.is_a?(URI::HTTPS) || uri.host.blank?

      origin_uri(uri)
    rescue URI::InvalidURIError
      raise NextcloudError.new(:not_configured)
    end

    def origin_uri(uri)
      port = uri.port == uri.default_port ? "" : ":#{uri.port}"
      URI.parse("https://#{uri.host.downcase}#{port}")
    end

    def perform(request_class, path, body: nil, query: {}, headers: {})
      uri = resolved_uri(path, query: query)
      request = build_request(request_class, uri, headers)
      if body.respond_to?(:read) && body.respond_to?(:size)
        body.rewind
        request.body_stream = body
        request.content_length = body.size
      elsif !body.nil?
        request.body = body
      end

      response = transmit(uri, request)
      if response.redirect?
        raise NextcloudError.new(:nextcloud_redirect_refused, status: response.status)
      end

      response
    end

    def build_request(request_class, uri, headers)
      request = request_class.new(uri)
      request["Accept"] = "application/json, application/xml;q=0.5"
      headers.each { |name, value| request[name.to_s] = value.to_s }
      request.basic_auth(@username, @password)
      request
    end

    def transmit(uri, request)
      response = nil
      # A socket read timeout alone permits an indefinitely trickling response.
      Timeout.timeout(@request_timeout) do
        http = build_http(uri)
        http.start do |connection|
          connection.request(request) do |raw|
            response = block_given? ? yield(raw) : read_response(raw)
          end
        end
      end
      response
    rescue Timeout::Error
      raise NextcloudError.new(:nextcloud_timeout)
    rescue OpenSSL::SSL::SSLError
      raise NextcloudError.new(:nextcloud_tls_error)
    rescue SocketError, SystemCallError, IOError
      raise NextcloudError.new(:nextcloud_unavailable)
    end

    def build_http(uri)
      addresses = FinalDestination::SSRFDetector.lookup_and_filter_ips(uri.hostname)
      http = Net::HTTP.new(uri.hostname, uri.port, nil)
      http.ipaddr = addresses.first
      http.max_retries = 0
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.min_version = MINIMUM_TLS_VERSION
      http.open_timeout = @open_timeout
      http.read_timeout = @read_timeout
      http.write_timeout = WRITE_TIMEOUT_SECONDS
      http
    rescue FinalDestination::SSRFDetector::DisallowedIpError
      raise NextcloudError.new(:nextcloud_private_address_refused)
    rescue FinalDestination::SSRFDetector::LookupFailedError
      raise NextcloudError.new(:nextcloud_unavailable)
    end

    def read_response(raw)
      body = +""
      raw.read_body do |chunk|
        body << chunk
        if body.bytesize > @max_response_bytes
          raise NextcloudError.new(:nextcloud_response_too_large)
        end
      end
      Response.new(status: raw.code.to_i, headers: normalized_headers(raw), body: body)
    end

    def normalized_headers(raw)
      raw.each_header.to_h { |name, value| [name.downcase, value] }
    end

    # Only internal paths, not caller-provided URLs or embedded query strings.
    def resolved_uri(path, query: {})
      unless path.is_a?(String) && path.start_with?("/") && !path.start_with?("//") &&
               !path.match?(/[\\\\?#[:cntrl:]]/)
        raise NextcloudError.new(:invalid_request_path)
      end
      uri = base_uri.dup
      uri.path = path
      uri.query = query.empty? ? nil : URI.encode_www_form(query)
      uri
    rescue URI::InvalidURIError, URI::InvalidComponentError
      raise NextcloudError.new(:invalid_request_path)
    end
  end
end
