# frozen_string_literal: true

module OfficePayloadSpecHelpers
  def upload(original_filename: "Plan.docx")
    Struct.new(:tempfile, :original_filename).new(StringIO.new("synthetic"), original_filename)
  end

  def document(params)
    DiscourseNextcloudOffice::DocumentPayload.new(
      { file_name: "Plan.docx", file_type: "docx", operation_key: "op-1" }.merge(params),
    ).validate!
  end

  def transfer(params)
    DiscourseNextcloudOffice::TransferPayload.new(
      { file: upload, file_name: "Plan.docx", file_type: "docx", operation_key: "op-1" }.merge(
        params,
      ),
    ).validate!
  end

  def expect_error(error_code)
    yield
  rescue DiscourseNextcloudOffice::RequestError => error
    expect(error.error_code).to eq(error_code)
  else
    raise "expected RequestError #{error_code}"
  end
end

RSpec.describe DiscourseNextcloudOffice::DocumentPayload do
  include OfficePayloadSpecHelpers

  it "normalizes a document request and treats a blank password as absent" do
    payload =
      document(
        file_name: "Prüfung.docx",
        file_type: "DOCX",
        share_password: "",
        operation_key: "op_1-test",
      )

    expect(payload.file_name).to eq("Prüfung.docx")
    expect(payload.file_type).to eq("docx")
    expect(payload.share_password).to be_nil
    expect(payload.operation_key).to eq("op_1-test")
  end

  it "uses a default file name when none is supplied" do
    expect(document(file_name: nil).file_name).to eq("Document.docx")
  end

  it "rejects arrays and nested objects instead of coercing them" do
    expect_error("invalid_parameters") { document(file_name: ["Plan.docx"]) }
    expect_error("invalid_parameters") { document(file_type: ["docx"]) }
    expect_error("invalid_parameters") { document(operation_key: { value: "op-1" }) }
  end

  it "rejects unsupported or non-template formats" do
    expect_error("unsupported_file_type") { document(file_type: "exe") }
    expect_error("unsupported_file_type") { document(file_type: "odt") }
    expect_error("invalid_parameters") { document(file_type: " docx") }
  end

  it "rejects mismatched extensions and unsafe operation keys" do
    expect_error("file_extension_mismatch") { document(file_name: "Plan.xlsx") }
    expect_error("invalid_operation_key") { document(operation_key: "../op-1") }
    expect_error("invalid_operation_key") { document(operation_key: "a" * 129) }
  end

  it "rejects unsafe share passwords without echoing them" do
    [" pass", "pass\nword", "a" * 257].each do |password|
      expect_error("invalid_share_password") { document(share_password: password) }
    end
  end
end

RSpec.describe DiscourseNextcloudOffice::TransferPayload do
  include OfficePayloadSpecHelpers

  it "accepts every supported upload format" do
    DiscourseNextcloudOffice::OfficeFormat::UPLOAD_FORMATS.each do |format|
      payload = transfer(file_name: "Plan.#{format}", file_type: format)
      expect(payload.file_name).to eq("Plan.#{format}")
    end
  end

  it "uses the uploaded original filename when none is supplied" do
    payload =
      transfer(file_name: nil, file_type: "xlsx", file: upload(original_filename: "Original.xlsx"))
    expect(payload.file_name).to eq("Original.xlsx")
  end

  it "requires a real uploaded file" do
    expect_error("invalid_parameters") { transfer(file: nil) }
    expect_error("invalid_parameters") { transfer(file: "not-a-file") }
  end

  it "rejects mismatched and missing names" do
    expect_error("file_extension_mismatch") { transfer(file_name: "Plan.docx", file_type: "xlsx") }
    expect_error("invalid_parameters") do
      transfer(file_name: nil, file: upload(original_filename: nil))
    end
  end
end
