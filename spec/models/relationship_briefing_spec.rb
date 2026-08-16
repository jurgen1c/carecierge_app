require "rails_helper"

# == Schema Information
#
# Table name: relationship_briefings
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  context_categories      :jsonb            not null
#  dismissed_at            :datetime
#  generated_at            :datetime         not null
#  include_private_notes   :boolean          default(FALSE), not null
#  include_vault_context   :boolean          default(FALSE), not null
#  interaction_context     :text             not null
#  locale                  :string           default("en"), not null
#  lock_version            :integer          default(0), not null
#  saved_at                :datetime
#  sections                :text             not null
#  status                  :string           default("generated"), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#  user_id                 :uuid             not null
#
# Indexes
#
#  index_relationship_briefings_on_one_generated_per_profile  (relationship_profile_id) UNIQUE WHERE ((status)::text = 'generated'::text)
#  index_relationship_briefings_on_profile_and_generated_at   (relationship_profile_id,generated_at DESC)
#  index_relationship_briefings_on_relationship_profile_id    (relationship_profile_id)
#  index_relationship_briefings_on_user_id                    (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
RSpec.describe RelationshipBriefing, type: :model do
  it "normalizes and bounds the private interaction context" do
    briefing = build(:relationship_briefing, interaction_context: "  Dinner after work.  ")

    expect(briefing).to be_valid
    expect(briefing.interaction_context).to eq("Dinner after work.")

    briefing.interaction_context = "x" * (described_class::MAX_INTERACTION_CONTEXT_LENGTH + 1)

    expect(briefing).not_to be_valid
    expect(briefing.errors.of_kind?(:interaction_context, :too_long)).to be(true)
  end

  it "rejects a relationship profile owned by another account" do
    briefing = build(
      :relationship_briefing,
      user: create(:user),
      relationship_profile: create(:relationship_profile)
    )

    expect(briefing).not_to be_valid
    expect(briefing.errors.of_kind?(:relationship_profile, :owner_mismatch)).to be(true)
  end

  it "encrypts the interaction context and generated sections at rest" do
    briefing = create(
      :relationship_briefing,
      interaction_context: "Discuss the private family update",
      sections: [
        {
          "key" => "sensitive_context",
          "items" => [
            {
              "body" => "Be thoughtful about the family update.",
              "certainty" => "confirmed",
              "sources" => [
                { "id" => "private_note:1", "label" => "Private note", "sensitive" => true }
              ]
            }
          ]
        }
      ]
    )

    raw = ApplicationRecord.connection.select_one(
      ApplicationRecord.sanitize_sql_array([
        "SELECT interaction_context, sections FROM relationship_briefings WHERE id = ?",
        briefing.id
      ])
    )

    expect(raw.fetch("interaction_context")).not_to include("private family update")
    expect(raw.fetch("sections")).not_to include("thoughtful about the family")
    expect(briefing.reload.interaction_context).to eq("Discuss the private family update")
    expect(briefing.sections.dig(0, "items", 0, "body")).to eq("Be thoughtful about the family update.")
  end

  it "supports explicit save and dismiss transitions" do
    generated_at = Time.zone.local(2026, 8, 15, 9)
    briefing = create(:relationship_briefing, generated_at:)

    Timecop.freeze(generated_at + 5.minutes) { briefing.save_for_later! }
    expect(briefing.reload).to have_attributes(status: "saved", saved_at: generated_at + 5.minutes)

    Timecop.freeze(generated_at + 10.minutes) { briefing.dismiss! }
    expect(briefing.reload).to have_attributes(status: "dismissed", dismissed_at: generated_at + 10.minutes)
  end

  it "rejects malformed generated sections" do
    briefing = build(:relationship_briefing, sections: [ { "key" => "invented", "items" => [] } ])

    expect(briefing).not_to be_valid
    expect(briefing.errors.of_kind?(:sections, :invalid)).to be(true)
  end
end
