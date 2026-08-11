require "rails_helper"

RSpec.describe MessageDraftPolicy do
  subject(:policy) { described_class.new(user, draft) }

  let(:user) { create(:user) }
  let(:draft) { create(:message_draft, user:) }

  it "allows the owner to update and destroy the draft" do
    expect(policy.update?).to be(true)
    expect(policy.destroy?).to be(true)
  end

  it "denies another account" do
    draft = create(:message_draft)

    other_policy = described_class.new(user, draft)
    expect(other_policy.update?).to be(false)
    expect(other_policy.destroy?).to be(false)
  end
end
