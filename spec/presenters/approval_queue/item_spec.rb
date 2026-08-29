require "rails_helper"

RSpec.describe ApprovalQueue::Item do
  it "presents the corrected extracted-memory title in completed history" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    proposal = create(
      :extracted_memory,
      relationship_profile: profile,
      conversation_recap: create(:conversation_recap, relationship_profile: profile),
      title: "Likes jazz",
      status: "corrected",
      corrected_title: "Enjoys intimate live jazz",
      corrected_body: "Enjoys intimate live jazz for special evenings."
    )
    approval_request = create(:approval_request, user:, subject: proposal, status: "approved", decided_at: Time.current)

    item = described_class.new(approval_request:)

    expect(item.title).to eq("Enjoys intimate live jazz")
    expect(item.proposed_action).to include("Enjoys intimate live jazz")
    expect(item.proposed_action).not_to include("Likes jazz")
  end
end
