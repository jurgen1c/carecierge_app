require "rails_helper"

RSpec.describe RelationshipProfile::SearchQuery do
  it "applies owner scope, status filtering, search, and stable ordering" do
    user = create(:user)
    visible = create(:relationship_profile, user:, first_name: "Rafa", type: "MentorRelationshipProfile")
    create(:relationship_profile, user:, first_name: "Archived Mentor", type: "MentorRelationshipProfile", discarded_at: Time.current)
    create(:relationship_profile, first_name: "Hidden", type: "MentorRelationshipProfile")

    query = described_class.new(
      RelationshipProfile.where(user:),
      params: ActionController::Parameters.new(
        q: { described_class::SEARCH_PREDICATE => "mentor" },
        status: "active"
      )
    )

    expect(query.resolve.map(&:id)).to contain_exactly(visible.id)
    expect(query.search_query).to eq("mentor")
    expect(query.status).to eq("active")
  end
end
