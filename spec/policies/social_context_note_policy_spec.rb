require "rails_helper"

RSpec.describe SocialContextNotePolicy, type: :policy do
  it "allows the active profile owner and rejects another user or an archived profile" do
    owner = create(:user)
    note = create(:social_context_note, relationship_profile: create(:relationship_profile, user: owner))

    expect(described_class.new(owner, note)).to have_attributes(update?: true, destroy?: true, analyze?: true)
    expect(described_class.new(create(:user), note)).to have_attributes(update?: false, destroy?: false, analyze?: false)

    note.relationship_profile.update!(discarded_at: Time.current)
    expect(described_class.new(owner, note)).to have_attributes(update?: false, destroy?: false, analyze?: false)
  end

  it "allows creation only through an active profile owned by the user" do
    owner = create(:user)
    active = build(:social_context_note, relationship_profile: create(:relationship_profile, user: owner))
    archived = build(:social_context_note, relationship_profile: create(:relationship_profile, user: owner, discarded_at: Time.current))

    expect(described_class.new(owner, active).create?).to be(true)
    expect(described_class.new(owner, archived).create?).to be(false)
    expect(described_class.new(create(:user), active).create?).to be(false)
  end
end
