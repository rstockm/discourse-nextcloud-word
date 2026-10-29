# frozen_string_literal: true

module ::DiscourseNextcloudOffice
  class OperationsController < ApplicationController
    wrap_parameters false
    MUTATING_ACTIONS = %i[create_document create_transfer].freeze

    before_action :enforce_request_body_limit, only: MUTATING_ACTIONS
    before_action :enforce_mutation_rate_limit, only: MUTATING_ACTIONS
    before_action :enforce_status_rate_limit, only: :show
    around_action :with_operation_slot, only: MUTATING_ACTIONS

    def create_document
      payload = DocumentPayload.new(params).validate!
      template = File.expand_path("../../../templates/template.#{payload.file_type}", __dir__)
      File.open(template, "rb") do |source|
        if source.size > Limits.max_file_bytes
          raise RequestError.new(:file_too_large, status: :payload_too_large)
        end
        PackageValidator.validate!(source, format: payload.file_type)
        render json:
                 OperationRunner.new(configuration).run(
                   user: current_user,
                   payload: payload,
                   source: source,
                 )
      end
    end

    def create_transfer
      payload = TransferPayload.new(params).validate!
      ::DiscourseNextcloudOffice::Limits.assert_upload_allowed!(
        payload.file_type,
        user: current_user,
      )
      ::DiscourseNextcloudOffice::Limits.assert_office_file_size!(payload.file)
      PackageValidator.validate!(payload.file, format: payload.file_type)
      render json:
               OperationRunner.new(configuration).run(
                 user: current_user,
                 payload: payload,
                 source: payload.file.tempfile,
               )
    end

    def show
      operation = Operation.find_by(user_id: current_user.id, operation_key: params[:operation_key])
      raise RequestError.new(:operation_not_found, status: :not_found) if operation.nil?
      if operation.state == "completed"
        render json: operation.result
      else
        raise RequestError.new(:operation_unknown, status: :conflict)
      end
    end

    private

    def enforce_request_body_limit
      ::DiscourseNextcloudOffice::Limits.assert_body_size!(
        request.content_length,
        multipart: action_name == "create_transfer",
      )
    end

    def enforce_mutation_rate_limit
      ::DiscourseNextcloudOffice::RateLimits.check_mutation!(current_user)
    end

    def enforce_status_rate_limit
      ::DiscourseNextcloudOffice::RateLimits.check_status!(current_user)
    end

    def with_operation_slot(&block)
      ::DiscourseNextcloudOffice::RateLimits.with_slot(current_user, &block)
    end
  end
end
