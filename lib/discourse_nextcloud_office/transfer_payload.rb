# frozen_string_literal: true

module ::DiscourseNextcloudOffice
  class TransferPayload < RequestPayload
    attr_reader :file, :file_name, :file_type, :operation_key

    def validate!
      @file_type = parse_file_type(allow: ::DiscourseNextcloudOffice::OfficeFormat::UPLOAD_FORMATS)
      @file = @params[:file]
      raise invalid_parameters if !@file.respond_to?(:tempfile)

      raw_name = param_string(:file_name, required: false)
      raw_name ||= @file.original_filename if @file.respond_to?(:original_filename)
      raise invalid_parameters if raw_name.nil?

      @file_name = ::DiscourseNextcloudOffice::FileName.normalize(raw_name, format: @file_type)
      @operation_key = parse_operation_key
      self
    end
  end
end
