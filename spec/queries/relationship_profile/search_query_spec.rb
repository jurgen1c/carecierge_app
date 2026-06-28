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

  it "searches relationship types by displayed English labels" do
    user = create(:user)
    best_friend = create(:relationship_profile, user:, first_name: "Maya", type: "BestFriendRelationshipProfile")
    in_law = create(:relationship_profile, user:, first_name: "Nora", type: "InLawRelationshipProfile")
    create(:relationship_profile, user:, first_name: "Rafa", type: "FriendRelationshipProfile")

    expect(resolve_ids(user:, query: "Best friend")).to contain_exactly(best_friend.id)
    expect(resolve_ids(user:, query: "In-law")).to contain_exactly(in_law.id)
  end

  it "searches relationship types by displayed Spanish labels" do
    user = create(:user)
    partner = create(:relationship_profile, user:, first_name: "Maya", type: "PartnerRelationshipProfile")
    create(:relationship_profile, user:, first_name: "Rafa", type: "FriendRelationshipProfile")

    I18n.with_locale(:es) do
      expect(resolve_ids(user:, query: "Pareja")).to contain_exactly(partner.id)
    end
  end

  def resolve_ids(user:, query:)
    described_class.new(
      RelationshipProfile.where(user:),
      params: ActionController::Parameters.new(
        q: { described_class::SEARCH_PREDICATE => query }
      )
    ).resolve.map(&:id)
  end
end
