# frozen_string_literal: true

require "digest"

module ::DiscourseNextcloudOffice
  class OperationRunner
    MAX_SECONDS = 90

    def initialize(configuration)
      @configuration = configuration
      @client = NextcloudClient.from_configuration(configuration)
      @webdav = Webdav.new(configuration, client: @client)
      @shares = Shares.new(configuration, client: @client)
    end

    def run(user:, payload:, source:)
      digest = Digest::SHA256.file(source.path).hexdigest
      fingerprint = Operation.fingerprint(payload, digest: digest)
      lock = "office-operation:#{user.id}:#{Digest::SHA256.hexdigest(payload.operation_key)}"

      Timeout.timeout(MAX_SECONDS) do
        DistributedMutex.synchronize(lock, validity: MAX_SECONDS + 10) do
          operation =
            Operation.claim!(
              user: user,
              payload: payload,
              fingerprint: fingerprint,
              target_path: @webdav.allocate_path(payload.file_name),
            )
          return operation.result if operation.state == "completed"
          if operation.state == "failed"
            raise RequestError.new(:operation_failed, status: :conflict)
          end

          recover_file!(operation, digest) if operation.state == "unknown"
          create_file!(operation, source) if operation.state == "pending"
          password = payload.respond_to?(:share_password) ? payload.share_password : nil
          share = @shares.find(operation.target_path, password_required: password.present?)
          share ||= @shares.create!(operation.target_path, password: password)
          operation.complete!(share)
        end
      end
    rescue Timeout::Error
      raise RequestError.new(:operation_unknown, status: :gateway_timeout), cause: nil
    rescue NextcloudError => error
      code = error.error_code == "file_conflict" ? :operation_conflict : :operation_unknown
      status = code == :operation_conflict ? :conflict : :bad_gateway
      raise RequestError.new(code, status: status), cause: nil
    end

    private

    def create_file!(operation, source)
      # The uncertainty marker must survive a crash before/after the PUT.
      operation.update!(state: "unknown", error_code: "file_outcome_unknown")
      metadata =
        @webdav.create!(operation.target_path, source: source, file_type: operation.file_type)
      operation.update!(state: "file_created", etag: metadata[:etag], error_code: nil)
    end

    def recover_file!(operation, digest)
      proof = @webdav.checksum(operation.target_path)
      if proof.nil?
        operation.update!(state: "pending", error_code: nil)
      elsif ActiveSupport::SecurityUtils.secure_compare(proof[:digest], digest)
        operation.update!(state: "file_created", etag: proof[:etag], error_code: nil)
      else
        raise NextcloudError.new(:file_conflict)
      end
    end
  end
end
