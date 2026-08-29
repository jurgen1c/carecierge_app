require "rails_helper"

# == Schema Information
#
# Table name: approval_requests
# Database name: primary
#
#  id                 :uuid             not null, primary key
#  action_key         :string           not null
#  confidence         :string
#  decided_at         :datetime
#  deferred_until     :datetime
#  kind               :string           not null
#  lock_version       :integer          default(0), not null
#  risk_level         :string           not null
#  status             :string           default("pending"), not null
#  subject_type       :string           not null
#  subject_updated_at :datetime         not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  subject_id         :uuid             not null
#  user_id            :uuid             not null
#
# Indexes
#
#  idx_approval_requests_one_open_action                         (user_id,subject_type,subject_id,action_key) UNIQUE WHERE ((status)::text = ANY ((ARRAY['pending'::character varying, 'deferred'::character varying])::text[]))
#  index_approval_requests_on_subject                            (subject_type,subject_id)
#  index_approval_requests_on_user_id                            (user_id)
#  index_approval_requests_on_user_id_and_status_and_created_at  (user_id,status,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
RSpec.describe ApprovalRequest do
  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:) }
  let(:subject) { create(:extracted_memory, relationship_profile: profile, conversation_recap: create(:conversation_recap, relationship_profile: profile)) }

  it "requires the subject to belong to the same owner" do
    request = described_class.new(
      user: create(:user),
      subject:,
      kind: "extracted_memory",
      action_key: "review_extracted_memory",
      risk_level: "medium",
      confidence: "medium"
    )

    expect(request).not_to be_valid
    expect(request.errors[:subject]).to be_present
  end

  it "keeps one open request per subject and action" do
    create(:approval_request, user:, subject:)
    duplicate = build(:approval_request, user:, subject:)

    expect(duplicate).not_to be_valid
  end

  it "returns due deferred requests to the pending view without mutating history" do
    Timecop.freeze(Time.zone.local(2026, 8, 28, 9)) do
      due = create(:approval_request, user:, subject:, status: "deferred", deferred_until: 1.day.from_now)
      due.update_column(:deferred_until, 1.minute.ago)
      future = create(:approval_request, user:, subject: create(:memory_record, relationship_profile: profile), kind: "memory_record", action_key: "approve_high_impact_memory", status: "deferred", deferred_until: 1.day.from_now)

      expect(described_class.pending_review).to contain_exactly(due)
      expect(described_class.deferred).to contain_exactly(future)
    end
  end

  it "preserves audit history when its source request is deleted" do
    approval_request = create(:approval_request, user:, subject:)
    approval_request.approval_decisions.create!(user:, decision: "dismiss", occurred_at: Time.current)
    audit_event = AuditEvent.record!(
      user:,
      actor: user,
      action: "approval.dismissed",
      target: approval_request,
      metadata: { request_kind: approval_request.kind, result: "dismiss" }
    )

    approval_request.destroy!

    expect(audit_event.reload).to have_attributes(target: nil, target_type: nil, target_id: nil)
    expect(ApprovalDecision.where(approval_request_id: approval_request.id)).to be_empty
  end
end
