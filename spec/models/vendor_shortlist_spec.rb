require "rails_helper"

# == Schema Information
#
# Table name: vendor_shortlists
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  lock_version            :integer          default(0), not null
#  title                   :text             not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  event_plan_id           :uuid
#  relationship_profile_id :uuid             not null
#  user_id                 :uuid             not null
#
# Indexes
#
#  index_vendor_shortlists_on_event_plan_id            (event_plan_id)
#  index_vendor_shortlists_on_profile_and_created_at   (relationship_profile_id,created_at)
#  index_vendor_shortlists_on_relationship_profile_id  (relationship_profile_id)
#  index_vendor_shortlists_on_user_id                  (user_id)
#  index_vendor_shortlists_on_user_id_and_created_at   (user_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (event_plan_id => event_plans.id) ON DELETE => cascade
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
RSpec.describe VendorShortlist, type: :model do
  it "belongs to one owner and relationship with an optional matching event plan" do
    shortlist = build(:vendor_shortlist)

    expect(shortlist).to be_valid
    expect(shortlist.user).to eq(shortlist.relationship_profile.user)
  end

  it "derives the relationship from its event plan" do
    plan = create(:event_plan)
    shortlist = build(:vendor_shortlist, user: plan.user, relationship_profile: nil, event_plan: plan)

    expect(shortlist).to be_valid
    expect(shortlist.relationship_profile).to eq(plan.relationship_profile)
  end

  it "rejects cross-owner and mismatched plan contexts" do
    user = create(:user)
    foreign_profile = create(:relationship_profile)
    foreign_plan = create(:event_plan)

    foreign = build(:vendor_shortlist, user:, relationship_profile: foreign_profile)
    mismatched = build(:vendor_shortlist, user:, relationship_profile: create(:relationship_profile, user:), event_plan: foreign_plan)

    expect(foreign).not_to be_valid
    expect(foreign.errors).to include(:relationship_profile)
    expect(mismatched).not_to be_valid
    expect(mismatched.errors).to include(:event_plan)
  end

  it "normalizes and bounds its encrypted title" do
    shortlist = build(:vendor_shortlist, title: "  Birthday   dinner options ")

    expect(shortlist).to be_valid
    expect(shortlist.title).to eq("Birthday dinner options")

    shortlist.title = "x" * (VendorShortlist::MAX_TITLE_LENGTH + 1)
    expect(shortlist).not_to be_valid
  end

  it "encrypts its private decision title at rest" do
    shortlist = create(:vendor_shortlist, title: "Private anniversary dinner options")
    raw = ApplicationRecord.connection.select_value(
      ApplicationRecord.sanitize_sql_array([ "SELECT title FROM vendor_shortlists WHERE id = ?", shortlist.id ])
    )

    expect(raw).not_to include("Private anniversary dinner options")
    expect(shortlist.reload.title).to eq("Private anniversary dinner options")
  end

  it "is mutable only while its relationship and optional plan are active" do
    relationship_shortlist = create(:vendor_shortlist)
    completed_plan_shortlist = create(:vendor_shortlist)
    completed_plan_shortlist.event_plan.complete!

    expect(relationship_shortlist).to be_mutable
    expect(completed_plan_shortlist).not_to be_mutable

    relationship_shortlist.relationship_profile.discard!
    expect(relationship_shortlist.reload).not_to be_mutable
  end


  it "does not create a shortlist for an inactive relationship or completed plan" do
    archived_profile = create(:relationship_profile, discarded_at: Time.current)
    completed_plan = create(:event_plan, status: "completed", completed_at: Time.current)

    expect(build(:vendor_shortlist, :relationship_need, user: archived_profile.user, relationship_profile: archived_profile)).not_to be_valid
    expect(build(:vendor_shortlist, user: completed_plan.user, relationship_profile: completed_plan.relationship_profile, event_plan: completed_plan)).not_to be_valid
  end
end
