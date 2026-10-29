# frozen_string_literal: true

RSpec.describe DiscourseNextcloudOffice::Operation do
  fab!(:user)
  let(:payload) do
    DiscourseNextcloudOffice::DocumentPayload.new(
      file_name: "Plan.docx",
      file_type: "docx",
      operation_key: "operation-1",
      share_password: "synthetic-secret",
    ).validate!
  end
  let(:fingerprint) { described_class.fingerprint(payload, digest: "synthetic-digest") }

  def claim
    described_class.claim!(
      user: user,
      payload: payload,
      fingerprint: fingerprint,
      target_path: "/Discourse/unique-Plan.docx",
    )
  end

  it "reuses a claim without changing its original target" do
    original = claim
    replay =
      described_class.claim!(
        user: user,
        payload: payload,
        fingerprint: fingerprint,
        target_path: "/Discourse/another-Plan.docx",
      )
    expect(replay.id).to eq(original.id)
    expect(replay.target_path).to eq(original.target_path)
  end

  it "rejects altered payloads for an existing key" do
    claim
    expect {
      described_class.claim!(
        user: user,
        payload: payload,
        fingerprint: "f" * 64,
        target_path: "/Discourse/other.docx",
      )
    }.to raise_error(DiscourseNextcloudOffice::RequestError, "operation_conflict")
  end

  it "enforces user/key uniqueness in the database, not just Ruby validation" do
    original = claim
    duplicate = original.dup
    duplicate.target_path = "/Discourse/other.docx"
    expect {
      described_class.transaction(requires_new: true) { duplicate.save!(validate: false) }
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "binds fingerprints to the file bytes and optional password" do
    original = fingerprint
    expect(original).not_to eq(described_class.fingerprint(payload, digest: "changed-bytes"))
    changed =
      DiscourseNextcloudOffice::DocumentPayload.new(
        file_name: "Plan.docx",
        file_type: "docx",
        operation_key: "operation-1",
        share_password: "another-secret",
      ).validate!
    expect(original).not_to eq(described_class.fingerprint(changed, digest: "synthetic-digest"))
  end

  it "encrypts results and persists neither password nor document bytes" do
    operation = claim
    share = { id: "42", url: "https://cloud.example.com/s/SyntheticToken", has_password: true }
    response = operation.complete!(share)
    expect(operation.reload.result).to eq(response.deep_stringify_keys)
    expect(operation.encrypted_result).not_to include(share[:url])
    expect(operation.attributes.to_json).not_to include(payload.share_password, "synthetic-digest")
    expect(operation.attributes.keys).not_to include("share_password", "file", "content")
  end

  it "purges only old completed local entries, preserving unresolved cases" do
    operation = claim
    operation.complete!(
      id: "42",
      url: "https://cloud.example.com/s/SyntheticToken",
      has_password: true,
    )
    operation.update!(completed_at: 8.days.ago)
    unresolved = operation.dup
    unresolved.assign_attributes(
      operation_key: "unresolved",
      target_path: "/Discourse/unresolved.docx",
      state: "unknown",
      completed_at: nil,
      encrypted_result: nil,
    )
    unresolved.save!

    expect(described_class.purge_completed!).to eq(1)
    expect(described_class.exists?(unresolved.id)).to eq(true)
    expect(a_request(:delete, /.*/)).not_to have_been_made
  end
end
