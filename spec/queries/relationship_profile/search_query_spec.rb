require "rails_helper"

RSpec.describe RelationshipProfile::SearchQuery do
  it "applies owner scope, status filtering, search, and stable ordering" do
    user = create(:user)
    visible = create(:relationship_profile, user:, first_name: "Rafa", relationship_type_name: "Mentor")
    create(:relationship_profile, user:, first_name: "Archived Mentor", relationship_type_name: "Mentor", discarded_at: Time.current)
    create(:relationship_profile, first_name: "Hidden", relationship_type_name: "Mentor")

    query = described_class.new(
      RelationshipProfile.where(user:),
      params: ActionController::Parameters.new(
        q: { described_class::SEARCH_PREDICATE => "mentor" },
        status: "active"
      )
    )

    expect(query.resolve).to contain_exactly(visible)
    expect(query.search_query).to eq("mentor")
    expect(query.status).to eq("active")
  end
end
