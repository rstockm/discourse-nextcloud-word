# frozen_string_literal: true

module ::DiscourseNextcloudOffice
  class Operation < ActiveRecord::Base
    self.table_name = "nextcloud_office_operations"
    STATES = %w[pending file_created completed failed unknown].freeze

    belongs_to :user
    validates :state, inclusion: { in: STATES }
    validates :operation_key, format: { with: RequestPayload::OPERATION_KEY_PATTERN }
    validates :fingerprint, format: { with: /\A[0-9a-f]{64}\z/ }
    validates :file_name, :file_type, :target_path, presence: true

    def self.claim!(user:, payload:, fingerprint:, target_path:)
      operation = find_by(user_id: user.id, operation_key: payload.operation_key)
      operation ||=
        create_or_find_by!(user_id: user.id, operation_key: payload.operation_key) do |record|
          record.assign_attributes(
            fingerprint: fingerprint,
            target_path: target_path,
            file_name: payload.file_name,
            file_type: payload.file_type,
          )
        end
      unless ActiveSupport::SecurityUtils.secure_compare(operation.fingerprint, fingerprint)
        raise RequestError.new(:operation_conflict, status: :conflict)
      end
      operation
    end

    def self.fingerprint(payload, digest:)
      content =
        JSON.generate(
          [
            payload.file_name,
            payload.file_type,
            digest,
            payload.respond_to?(:share_password) ? payload.share_password : nil,
          ],
        )
      OpenSSL::HMAC.hexdigest(
        "SHA256",
        Rails.application.key_generator.generate_key("discourse-nextcloud-office/fingerprint", 32),
        content,
      )
    end

    def result
      return nil if state != "completed"

      self.class.encryptor.decrypt_and_verify(encrypted_result, purpose: "office-result")
    rescue ActiveSupport::MessageEncryptor::InvalidMessage
      raise RequestError.new(:operation_unavailable, status: :service_unavailable), cause: nil
    end

    def complete!(share)
      response = {
        success: true,
        operation_key: operation_key,
        url: share.fetch(:url),
        file_name: file_name,
        file_type: file_type,
        has_password: share.fetch(:has_password),
      }
      update!(
        state: "completed",
        completed_at: Time.current,
        error_code: nil,
        encrypted_result: self.class.encryptor.encrypt_and_sign(response, purpose: "office-result"),
      )
      response
    end

    def self.encryptor
      key = Rails.application.key_generator.generate_key("discourse-nextcloud-office/result", 32)
      ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm", serializer: JSON)
    end

    def self.purge_completed!
      ids =
        where(state: "completed")
          .where("completed_at < ?", 7.days.ago)
          .order(:id)
          .limit(500)
          .pluck(:id)
      where(id: ids, state: "completed").delete_all
    end
  end
end
