require "rails_helper"

RSpec.describe PersonalTouchItemPolicy do
  it "allows checklist mutations only for the active relationship owner" do
    item = create(:personal_touch_item)
    owner = item.personal_touch_checklist.relationship_profile.user

    owner_policy = described_class.new(owner, item)
    foreign_policy = described_class.new(create(:user), item)

    %i[create complete reopen dismiss move_up move_down].each do |action|
      expect(owner_policy.public_send("#{action}?")).to be(true)
      expect(foreign_policy.public_send("#{action}?")).to be(false)
    end
  end
end
