# frozen_string_literal: true

RSpec.describe DiscourseNextcloudOffice::Limits do
  fab!(:user)
  fab!(:staff, :moderator)

  def expect_error(error_code)
    yield
  rescue DiscourseNextcloudOffice::RequestError => error
    expect(error.error_code).to eq(error_code)
  else
    raise "expected RequestError #{error_code}"
  end

  describe ".max_file_bytes" do
    it "uses the plugin setting" do
      SiteSetting.nextcloud_office_max_file_size_mb = 10

      expect(described_class.max_file_bytes).to eq(10.megabytes)
    end

    it "never exceeds the site's attachment limit" do
      SiteSetting.nextcloud_office_max_file_size_mb = 25
      SiteSetting.max_attachment_size_kb = 1_024

      expect(described_class.max_file_bytes).to eq(1.megabyte)

      SiteSetting.max_attachment_size_kb = 1

      expect(described_class.max_file_bytes).to eq(1.kilobyte)
    end
  end

  describe ".max_body_bytes" do
    it "adds a bounded multipart overhead and caps JSON bodies" do
      SiteSetting.nextcloud_office_max_file_size_mb = 4

      expect(described_class.max_body_bytes(multipart: true)).to eq(
        4.megabytes + described_class::MULTIPART_OVERHEAD_BYTES,
      )
      expect(described_class.max_body_bytes(multipart: false)).to eq(
        described_class::JSON_BODY_BYTES,
      )
    end
  end

  describe ".assert_body_size!" do
    before { SiteSetting.nextcloud_office_max_file_size_mb = 4 }

    it "accepts missing or small content lengths" do
      expect { described_class.assert_body_size!(nil, multipart: true) }.not_to raise_error
      expect { described_class.assert_body_size!(1_000, multipart: false) }.not_to raise_error
    end

    it "rejects oversized JSON and multipart bodies" do
      expect_error("request_too_large") do
        described_class.assert_body_size!(described_class::JSON_BODY_BYTES + 1, multipart: false)
      end
      expect_error("request_too_large") do
        described_class.assert_body_size!(
          described_class.max_body_bytes(multipart: true) + 1,
          multipart: true,
        )
      end
    end
  end

  describe ".assert_office_file_size!" do
    it "rejects files above the effective limit" do
      SiteSetting.nextcloud_office_max_file_size_mb = 1
      file = Struct.new(:tempfile).new(Tempfile.new.tap { |temp| temp.write("x" * (1.megabyte + 1)) })

      expect_error("file_too_large") { described_class.assert_office_file_size!(file) }
    ensure
      file&.tempfile&.close!
    end
  end

  describe ".upload_extension_allowed?" do
    it "follows the site's authorized extensions" do
      SiteSetting.authorized_extensions = "jpg|png"

      expect(described_class.upload_extension_allowed?("docx", user: user)).to eq(false)

      SiteSetting.authorized_extensions = "jpg|png|docx"

      expect(described_class.upload_extension_allowed?("docx", user: user)).to eq(true)
    end

    it "honours staff-only extensions and wildcards" do
      SiteSetting.authorized_extensions = "jpg"
      SiteSetting.authorized_extensions_for_staff = "docx"

      expect(described_class.upload_extension_allowed?("docx", user: user)).to eq(false)
      expect(described_class.upload_extension_allowed?("docx", user: staff)).to eq(true)

      SiteSetting.authorized_extensions = "*"

      expect(described_class.upload_extension_allowed?("odp", user: user)).to eq(true)
    end

    it "is case and whitespace tolerant like the upload validator" do
      SiteSetting.authorized_extensions = " jpg | DOCX "

      expect(described_class.upload_extension_allowed?("docx", user: user)).to eq(true)
    end
  end

  describe ".assert_upload_allowed!" do
    it "raises a safe 415 for formats the site does not accept" do
      SiteSetting.authorized_extensions = "jpg"

      expect {
        described_class.assert_upload_allowed!("docx", user: user)
      }.to raise_error(DiscourseNextcloudOffice::RequestError) do |error|
        expect(error.error_code).to eq("file_type_not_allowed")
        expect(error.status).to eq(:unsupported_media_type)
      end
    end
  end
end
