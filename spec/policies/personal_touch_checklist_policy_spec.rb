require "rails_helper"

RSpec.describe PersonalTouchChecklistPolicy do
  it "scopes checklists to the owner and active relationships" do
    owned = create(:personal_touch_checklist)
    foreign = create(:personal_touch_checklist)

    resolved = described_class::Scope.new(owned.relationship_profile.user, PersonalTouchChecklist).resolve

    expect(resolved).to contain_exactly(owned)
    expect(resolved).not_to include(foreign)

    owned.relationship_profile.archive!
    expect(described_class::Scope.new(owned.relationship_profile.user, PersonalTouchChecklist).resolve).to be_empty
  end

  it "allows only the active relationship owner" do
    checklist = create(:personal_touch_checklist)

    expect(described_class.new(checklist.relationship_profile.user, checklist).update?).to be(true)
    expect(described_class.new(create(:user), checklist).update?).to be(false)
  end
end
