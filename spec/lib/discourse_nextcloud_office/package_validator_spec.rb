# frozen_string_literal: true

RSpec.describe DiscourseNextcloudOffice::PackageValidator do
  include OfficePackageHelpers

  after { cleanup_office_packages }

  def expect_invalid(source, format:, limits: {}, clock: nil)
    expect {
      described_class.validate!(source, format: format, limits: limits, clock: clock)
    }.to raise_error(DiscourseNextcloudOffice::RequestError) do |error|
      expect(error.error_code).to eq("invalid_file_content")
      expect(error.status).to eq(:unsupported_media_type)
    end
  end

  it "accepts all six upload fixtures" do
    DiscourseNextcloudOffice::OfficeFormat::UPLOAD_FORMATS.each do |format|
      expect(
        described_class.validate!(office_fixture_path("upload.#{format}"), format: format),
      ).to eq(true)
    end
  end

  it "accepts the three template fixtures" do
    %w[docx xlsx pptx].each do |format|
      expect(
        described_class.validate!(office_fixture_path("template.#{format}"), format: format),
      ).to eq(true)
    end
  end

  it "rejects a package validated as a different format" do
    expect_invalid(office_fixture_path("upload.docx"), format: "xlsx")
    expect_invalid(office_fixture_path("upload.odt"), format: "ods")
  end

  it "rejects empty, malformed and generic ZIP packages" do
    expect_invalid(empty_office_file, format: "docx")
    expect_invalid(build_office_package({ "readme.txt" => "not an office package" }), format: "docx")
    expect_invalid(
      build_office_package({ "word/document.xml" => "<w:document/>" }),
      format: "docx",
    )
  end

  it "rejects macro-enabled packages" do
    expect_invalid(
      modified_office_package("upload.docx", add: { "word/vbaProject.bin" => "macro" }),
      format: "docx",
    )

    macro_types =
      package_entries("upload.docx")["[Content_Types].xml"].sub(
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml",
        "application/vnd.ms-word.document.macroEnabled.main+xml",
      )
    expect_invalid(
      modified_office_package("upload.docx", replace: { "[Content_Types].xml" => macro_types }),
      format: "docx",
    )
  end

  it "rejects encrypted OOXML and ODF containers" do
    expect_invalid(
      build_office_package({ "EncryptionInfo" => "x", "EncryptedPackage" => "x" }),
      format: "docx",
    )

    encrypted_manifest =
      package_entries("upload.odt")["META-INF/manifest.xml"].sub(
        "</manifest:manifest>",
        "<manifest:encryption-data/></manifest:manifest>",
      )
    expect_invalid(
      modified_office_package("upload.odt", replace: { "META-INF/manifest.xml" => encrypted_manifest }),
      format: "odt",
    )
  end

  it "rejects ODF packages with a wrong, compressed or missing mimetype" do
    entries = package_entries("upload.odt")
    expect_invalid(build_office_package(entries, stored: []), format: "odt")

    wrong_mime = entries.merge("mimetype" => "application/zip")
    expect_invalid(build_office_package(wrong_mime, stored: ["mimetype"]), format: "odt")

    without_mime = entries.reject { |name, _| name == "mimetype" }
    expect_invalid(build_office_package(without_mime, stored: []), format: "odt")
  end

  it "rejects XML declarations with DTDs or entities" do
    doctype =
      "<!DOCTYPE foo [<!ENTITY xxe SYSTEM \"file:///etc/passwd\">]>" \
        "<office:document-content xmlns:office=\"urn:oasis:names:tc:opendocument:xmlns:office:1.0\">" \
        "<office:body><office:text>&xxe;</office:text></office:body></office:document-content>"
    expect_invalid(
      modified_office_package("upload.odt", replace: { "content.xml" => doctype }),
      format: "odt",
    )
  end

  it "rejects broken XML in an otherwise valid package" do
    expect_invalid(
      modified_office_package("upload.docx", replace: { "word/document.xml" => "<not-closed>" }),
      format: "docx",
    )
  end

  it "rejects damaged ZIP containers" do
    path = build_office_package(package_entries("upload.docx"))
    File.binwrite(path, File.binread(path)[0..-20])

    expect_invalid(path, format: "docx")
  end

  it "enforces entry, per-entry and total byte budgets" do
    source = office_fixture_path("upload.docx")

    expect_invalid(source, format: "docx", limits: { max_entries: 2 })
    expect_invalid(source, format: "docx", limits: { max_entry_bytes: 10 })
    expect_invalid(source, format: "docx", limits: { max_total_bytes: 10 })
  end

  it "enforces the extraction time budget" do
    calls = 0
    clock = -> {
      calls += 1
      calls == 1 ? 0.0 : 6.0
    }

    expect_invalid(
      office_fixture_path("upload.docx"),
      format: "docx",
      limits: { max_seconds: 5.0 },
      clock: clock,
    )
  end

  it "rejects traversal entries in a real package" do
    traversal = package_entries("upload.docx")
    traversal["../escape.txt"] = "outside"
    expect_invalid(build_office_package(traversal), format: "docx")

    expect_invalid(
      build_raw_zip([{ name: "word/../../escape.xml" }, { name: "^.xml" }]),
      format: "docx",
    )
  end

  it "rejects symlink entries" do
    path =
      build_raw_zip(
        [{ name: "word/link.xml", data: "../../../../etc/passwd", mode: 0o120777 }],
      )

    validator = described_class.new(path, format: "docx")
    expect(validator.send(:central_directory).first[:mode] & 0o170000).to eq(0o120000)
    expect(validator.send(:symlink_mode?, 0o120777)).to eq(true)

    expect_invalid(path, format: "docx")
  end

  it "rejects duplicate entry names from the raw central directory" do
    path =
      build_raw_zip(
        [{ name: "word/document.xml", data: "a" }, { name: "word/document.xml", data: "b" }],
      )

    # rubyzip hides the second record; the validator must not rely on it.
    expect(::Zip::File.open(path) { |zip| zip.entries.map(&:name) }).to eq(["word/document.xml"])
    expect(described_class.new(path, format: "docx").send(:central_directory).length).to eq(2)

    expect_invalid(path, format: "docx")
  end

  it "rejects inconsistent or oversized central directories" do
    source = build_office_package(package_entries("upload.docx"))

    expect_invalid(source, format: "docx", limits: { max_central_directory_bytes: 10 })
    expect_invalid(source, format: "docx", limits: { max_entries: 1 })
  end

  it "does not create its own temporary files while inspecting a package" do
    allow(Tempfile).to receive(:new).and_call_original

    expect(described_class.validate!(office_fixture_path("upload.docx"), format: "docx")).to eq(true)
    expect(Tempfile).not_to have_received(:new)
  end

  it "releases every file handle, including after a rejection" do
    source = office_fixture_path("upload.docx")
    handle_count = -> { Dir.children("/dev/fd").length }

    described_class.validate!(source, format: "docx")
    before = handle_count.call

    5.times { described_class.validate!(source, format: "docx") }
    5.times { expect_invalid(build_office_package({ "readme.txt" => "nope" }), format: "docx") }

    expect(handle_count.call).to be <= before + 1
  end
end
