require "rails_helper"

RSpec.describe MoodNotePolicy do
  let(:owner) { create(:user) }
  let(:profile) { create(:relationship_profile, user: owner) }
  let(:mood_note) { create(:mood_note, relationship_profile: profile) }

  it "allows the relationship owner to manage and scope mood notes" do
    policy = described_class.new(owner, mood_note)

    expect(policy.create?).to be(true)
    expect(policy.update?).to be(true)
    expect(policy.destroy?).to be(true)
    expect(described_class::Scope.new(owner, MoodNote).resolve).to contain_exactly(mood_note)
  end

  it "denies another user and excludes the note from their scope" do
    other_user = create(:user)
    policy = described_class.new(other_user, mood_note)

    expect(policy.create?).to be(false)
    expect(policy.update?).to be(false)
    expect(policy.destroy?).to be(false)
    expect(described_class::Scope.new(other_user, MoodNote).resolve).to be_empty
  end
end
