require "rails_helper"

# == Schema Information
#
# Table name: personal_touch_checklists
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  event_plan_id           :uuid
#  important_date_id       :uuid
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  idx_personal_touch_checklists_unique_event_plan             (event_plan_id) UNIQUE WHERE (event_plan_id IS NOT NULL)
#  idx_personal_touch_checklists_unique_important_date         (important_date_id) UNIQUE WHERE (important_date_id IS NOT NULL)
#  index_personal_touch_checklists_on_relationship_profile_id  (relationship_profile_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_plan_id => event_plans.id) ON DELETE => cascade
#  fk_rails_...  (important_date_id => important_dates.id) ON DELETE => cascade
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#
RSpec.describe PersonalTouchChecklist do
  it "attaches to an owned event plan" do
    plan = create(:event_plan)

    checklist = build(
      :personal_touch_checklist,
      relationship_profile: plan.relationship_profile,
      event_plan: plan
    )

    expect(checklist).to be_valid
  end

  it "attaches to an owned important date" do
    important_date = create(:important_date)

    checklist = build(
      :personal_touch_checklist,
      relationship_profile: important_date.relationship_profile,
      event_plan: nil,
      important_date:
    )

    expect(checklist).to be_valid
  end

  it "requires exactly one supported relationship moment" do
    checklist = build(:personal_touch_checklist, event_plan: nil, important_date: nil)

    expect(checklist).not_to be_valid

    checklist.event_plan = create(:event_plan, user: checklist.relationship_profile.user, relationship_profile: checklist.relationship_profile)
    checklist.important_date = create(:important_date, relationship_profile: checklist.relationship_profile)

    expect(checklist).not_to be_valid
  end

  it "rejects a moment from another relationship profile" do
    checklist = build(:personal_touch_checklist)
    checklist.event_plan = create(:event_plan)

    expect(checklist).not_to be_valid
  end

  it "exposes the attached moment without a polymorphic persistence boundary" do
    checklist = create(:personal_touch_checklist)

    expect(checklist.moment).to eq(checklist.event_plan)
  end

  it "locks the owning account before the profile and checklist during mutations" do
    checklist = create(:personal_touch_checklist)
    profile = checklist.relationship_profile
    owner = profile.user

    expect(owner).to receive(:with_lock).ordered.and_call_original
    expect(profile).to receive(:with_lock).ordered.and_call_original
    expect(checklist).to receive(:with_lock).ordered.and_call_original

    checklist.with_mutation_lock { nil }
  end

  it "uses only the unique partial index for each optional moment" do
    moment_indexes = described_class.connection.indexes(described_class.table_name).select do |index|
      index.columns.one? && index.columns.first.in?(%w[event_plan_id important_date_id])
    end

    expect(moment_indexes.map(&:name)).to contain_exactly(
      "idx_personal_touch_checklists_unique_event_plan",
      "idx_personal_touch_checklists_unique_important_date"
    )
    expect(moment_indexes.map(&:unique)).to all(be(true))
  end
end
