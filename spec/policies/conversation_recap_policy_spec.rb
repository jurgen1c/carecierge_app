require "rails_helper"

RSpec.describe ConversationRecapPolicy, type: :policy do
  it "allows the profile owner to retry extraction and rejects another user" do
    owner = create(:user)
    recap = create(:conversation_recap, relationship_profile: create(:relationship_profile, user: owner))

    expect(described_class.new(owner, recap).retry_extraction?).to be(true)
    expect(described_class.new(create(:user), recap).retry_extraction?).to be(false)
  end
end
