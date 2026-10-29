# frozen_string_literal: true

module ::DiscourseNextcloudOffice
  class DocumentPayload < RequestPayload
    attr_reader :file_name, :file_type, :share_password, :operation_key

    def validate!
      @file_type = parse_file_type(allow: ::DiscourseNextcloudOffice::OfficeFormat::TEMPLATE_FORMATS)

      raw_name = param_string(:file_name, required: false) || ::DiscourseNextcloudOffice::FileName::DEFAULT
      @file_name = ::DiscourseNextcloudOffice::FileName.normalize(raw_name, format: @file_type)
      @share_password = parse_share_password
      @operation_key = parse_operation_key
      self
    end
  end
end
