require "rails_helper"

RSpec.describe MessageDraftWorkspaceComponent, type: :component do
  it "does not prefill a failed personal generation's saved situation in professional mode" do
    profile = create(:relationship_profile)
    draft = create(:message_draft, user: profile.user, relationship_profile: profile, situation: "Personal medical discussion")
    profile.update!(relationship_mode: "professional")
    render_inline described_class.new(relationship_profile: profile, message_draft: draft.reload)
    expect(page).to have_field("Message or situation", with: "")
    expect(page).not_to have_text("Personal medical discussion")
  end
end
