# frozen_string_literal: true

RSpec.describe DiscourseNextcloudOffice::FileName do
  def normalize(value, format: "docx")
    described_class.normalize(value, format: format)
  end

  it "keeps Unicode and applies exactly one matching extension" do
    expect(normalize("Prüfung Änderung.docx")).to eq("Prüfung Änderung.docx")
    expect(normalize("Prüfung Änderung", format: "odt")).to eq("Prüfung Änderung.odt")
  end

  it "removes path separators and leading traversal dots" do
    expect(normalize("../../Secret.docx")).to eq("Secret.docx")
    expect(normalize("..\\..\\Secret.docx")).to eq("Secret.docx")
    expect(normalize("Ordner/Unterordner/Plan.docx")).to eq("OrdnerUnterordnerPlan.docx")
  end

  it "normalizes duplicate and mismatched extensions safely" do
    expect(normalize("Plan.docx.docx")).to eq("Plan.docx")
    expect(normalize("Plan.DOCX")).to eq("Plan.docx")
    expect(normalize("Plan.final.docx")).to eq("Plan.final.docx")
    expect(normalize("Plan v1.2.docx")).to eq("Plan v1.2.docx")

    expect { normalize("Plan.xlsx") }.to raise_error(DiscourseNextcloudOffice::RequestError) do |error|
      expect(error.error_code).to eq("file_extension_mismatch")
    end
    expect { normalize("Plan.docx.exe") }.to raise_error(
      DiscourseNextcloudOffice::RequestError,
    ) { |error| expect(error.error_code).to eq("file_extension_mismatch") }
  end

  it "removes control, bidi and HTML-significant characters" do
    expect(normalize("Plan\u0000.docx")).to eq("Plan.docx")
    expect(normalize("Plan\u202Ecod.docx")).to eq("Plancod.docx")
    expect(normalize("<script>alert(1)</script>.docx")).to eq("scriptalert(1)script.docx")
  end

  it "collapses whitespace, trims dots and falls back to a default name" do
    expect(normalize("  Plan   2026.docx  ")).to eq("Plan 2026.docx")
    expect(normalize("...")).to eq("Document.docx")
    expect(normalize("", format: "xlsx")).to eq("Document.xlsx")
  end

  it "truncates on UTF-8 byte boundaries within the byte budget" do
    result = normalize("#{"ä" * 150}.docx")

    expect(result.bytesize).to be <= described_class::MAX_BYTES
    expect(result).to end_with(".docx")
    expect(result).to be_valid_encoding
  end

  it "rejects non-string and invalid UTF-8 names" do
    [nil, ["Plan.docx"], { name: "Plan.docx" }].each do |value|
      expect { normalize(value) }.to raise_error(DiscourseNextcloudOffice::RequestError) do |error|
        expect(error.error_code).to eq("invalid_file_name")
      end
    end

    invalid = "Plan\xFF.docx".b.force_encoding(Encoding::UTF_8)
    expect { normalize(invalid) }.to raise_error(DiscourseNextcloudOffice::RequestError) do |error|
      expect(error.error_code).to eq("invalid_file_name")
    end
  end
end
