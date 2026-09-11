require "rails_helper"

RSpec.describe "Concierge relationship context", type: :request do
  let(:user) { create(:user, onboarding_completed_at: Time.current) }
  let(:profile) { create(:relationship_profile, user:) }
  let(:conversation) { ConciergeConversation.create!(user:, relationship_profile: profile) }

  before { sign_in user }

  it "saves reviewed context in Spanish and returns to a new chat without a provider request" do
    note = profile.relationship_notes.create!(category: "Work", body: "Meeting agenda", private: false)
    get edit_concierge_conversation_relationship_context_path(conversation, locale: "es")
    expect(response).to have_http_status(:ok)
    expect(response.headers["Cache-Control"]).to include("no-store")
    document = Nokogiri::HTML(response.body)
    expect(document.at_css('select[name="relationship_profile[relationship_mode]"]')).to be_present
    version = document.at_css('input[name="expected_version"]')["value"]
    patch concierge_conversation_relationship_context_path(conversation, locale: "es"), params: {
      expected_version: version, relationship_profile: { relationship_mode: "professional", professional_context: { relationship_notes: [ note.id ] } }
    }
    expect(response).to have_http_status(:see_other)
    updated = user.concierge_conversations.where.not(id: conversation.id).sole
    expect(response).to redirect_to(concierge_conversation_path(updated, locale: "es"))
    expect(updated.turns).to be_empty
    expect(profile.reload.work_context.selected("relationship_notes").pluck(:id)).to eq([ note.id ])
  end

  it "hides foreign conversations and recovers invalid selections without changing the relationship" do
    foreign = ConciergeConversation.create!(user: create(:user))
    get edit_concierge_conversation_relationship_context_path(foreign)
    expect(response).to have_http_status(:not_found)
    patch concierge_conversation_relationship_context_path(conversation), params: {
      expected_version: Concierge::RecordVersion.for(profile), relationship_profile: {
        relationship_mode: "professional", professional_context: { relationship_notes: [ SecureRandom.uuid ] }
      }
    }
    expect(response).to have_http_status(:unprocessable_content)
    expect(profile.reload).not_to be_professional
    expect(user.concierge_conversations.count).to eq(1)
  end
end
