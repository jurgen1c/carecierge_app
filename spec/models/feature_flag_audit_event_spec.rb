# == Schema Information
#
# Table name: feature_flag_audit_events
# Database name: primary
#
#  id              :uuid             not null, primary key
#  action          :string           not null
#  details         :jsonb            not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  actor_id        :uuid
#  feature_flag_id :uuid             not null
#
# Indexes
#
#  index_feature_flag_audit_events_on_action           (action)
#  index_feature_flag_audit_events_on_actor_id         (actor_id)
#  index_feature_flag_audit_events_on_feature_flag_id  (feature_flag_id)
#
# Foreign Keys
#
#  fk_rails_...  (actor_id => users.id)
#  fk_rails_...  (feature_flag_id => feature_flags.id)
#
require "rails_helper"

RSpec.describe FeatureFlagAuditEvent, type: :model do
  it { is_expected.to belong_to(:feature_flag) }
  it { is_expected.to belong_to(:actor).class_name("User").optional }
  it { is_expected.to validate_presence_of(:action) }

  it "stores auditable feature flag change details" do
    audit_event = create(
      :feature_flag_audit_event,
      action: "assignment_created",
      details: { "target_kind" => "environment", "target_value" => "staging" }
    )

    expect(audit_event).to be_persisted
    expect(audit_event.details).to include(
      "target_kind" => "environment",
      "target_value" => "staging"
    )
  end
end
