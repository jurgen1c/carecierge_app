require "rails_helper"

# == Schema Information
#
# Table name: concierge_conversations
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  title                   :text
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid
#  user_id                 :uuid             not null
#
# Indexes
#
#  idx_concierge_conversations_history                       (user_id,updated_at,id)
#  index_concierge_conversations_on_relationship_profile_id  (relationship_profile_id)
#  index_concierge_conversations_on_user_id                  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id)
#
RSpec.describe "Concierge conversation persistence", type: :model do
  let(:user) { create(:user) }

  it "encrypts the conversation title and cascades private turns on account deletion" do
    conversation = ConciergeConversation.create!(user:, title: "Planning Ana's birthday")
    turn = conversation.turns.create!(request_key: SecureRandom.uuid, content: "Ana prefers quiet restaurants", locale: "en")

    expect(conversation.reload.title).to eq("Planning Ana's birthday")
    expect(conversation.title_before_type_cast).not_to include("Ana")
    expect(turn.reload.content).to eq("Ana prefers quiet restaurants")
    expect(turn.content_before_type_cast).not_to include("restaurants")

    expect { user.destroy! }.to change(ConciergeConversation, :count).by(-1)
      .and change(ConciergeTurn, :count).by(-1)
  end

  it "rejects a relationship owned by another account" do
    conversation = ConciergeConversation.new(user:, relationship_profile: create(:relationship_profile))

    expect(conversation).not_to be_valid
    expect(conversation.errors[:relationship_profile]).to be_present
  end

  it "allows an owned active relationship and rejects an archived relationship" do
    profile = create(:relationship_profile, user:)
    conversation = ConciergeConversation.create!(user:, relationship_profile: profile)

    profile.archive!

    expect(conversation.reload).not_to be_context_available
  end

  it "authorizes history only for its owner" do
    conversation = ConciergeConversation.create!(user:)
    stranger = create(:user)

    expect(ConciergeConversationPolicy.new(user, conversation).show?).to be(true)
    expect(ConciergeConversationPolicy.new(stranger, conversation).show?).to be(false)
    expect(ConciergeConversationPolicy::Scope.new(stranger, ConciergeConversation).resolve).to be_empty
  end
end
