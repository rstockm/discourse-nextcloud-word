# frozen_string_literal: true

module OfficeNextcloudHelpers
  def stub_office_nextcloud(username: "office-service", share_failures: 0)
    @office_files = {}
    @office_shares = {}
    @office_share_id = 0
    @office_share_failures = share_failures
    dav_root = "/remote.php/dav/files/#{username}"
    dav = %r{\Ahttps://cloud\.example\.com#{Regexp.escape(dav_root)}/}
    ocs = %r{\Ahttps://cloud\.example\.com/ocs/v2\.php/apps/files_sharing/api/v1/shares(?:\?|$)}

    stub_request(:put, dav)
      .with(headers: { "If-None-Match" => "*" })
      .to_return do |request|
        path = URI::DEFAULT_PARSER.unescape(request.uri.path.delete_prefix(dav_root))
        if @office_files.key?(path)
          { status: 412 }
        else
          @office_files[path] = request.body
          { status: 201, headers: { "ETag" => '"synthetic-etag"' } }
        end
      end
    stub_request(:get, dav).to_return do |request|
      path = URI::DEFAULT_PARSER.unescape(request.uri.path.delete_prefix(dav_root))
      if @office_files.key?(path)
        { status: 200, body: @office_files[path], headers: { "ETag" => '"synthetic-etag"' } }
      else
        { status: 404 }
      end
    end
    stub_request(:get, ocs).to_return do |request|
      path = URI.decode_www_form(request.uri.query).to_h.fetch("path")
      { status: 200, body: office_ocs_envelope(@office_shares.fetch(path, [])) }
    end
    stub_request(:post, ocs).to_return do |request|
      if @office_share_failures.positive?
        @office_share_failures -= 1
        next({ status: 503, body: "synthetic upstream failure" })
      end
      fields = URI.decode_www_form(request.body).to_h
      @office_share_id += 1
      token = "SyntheticToken#{@office_share_id}"
      share = {
        "id" => @office_share_id.to_s,
        "path" => fields.fetch("path"),
        "uid_owner" => username,
        "item_type" => "file",
        "share_type" => 3,
        "permissions" => 3,
        "password" => fields["password"].present? ? "redacted" : nil,
        "token" => token,
        "url" => "https://cloud.example.com/s/#{token}",
      }
      (@office_shares[fields.fetch("path")] ||= []) << share
      { status: 200, body: office_ocs_envelope(share) }
    end
  end

  def office_ocs_envelope(data)
    { ocs: { meta: { status: "ok", statuscode: 200 }, data: data } }.to_json
  end
end
