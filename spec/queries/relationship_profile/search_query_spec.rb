require "rails_helper"

RSpec.describe RelationshipProfile::SearchQuery do
  it "applies owner scope, status filtering, search, and stable ordering" do
    user = create(:user)
    visible = create(:relationship_profile, user:, first_name: "Rafa", type: "RelationshipProfiles::Mentor")
    create(:relationship_profile, user:, first_name: "Archived Mentor", type: "RelationshipProfiles::Mentor", discarded_at: Time.current)
    create(:relationship_profile, first_name: "Hidden", type: "RelationshipProfiles::Mentor")

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
    best_friend = create(:relationship_profile, user:, first_name: "Maya", type: "RelationshipProfiles::BestFriend")
    in_law = create(:relationship_profile, user:, first_name: "Nora", type: "RelationshipProfiles::InLaw")
    create(:relationship_profile, user:, first_name: "Rafa", type: "RelationshipProfiles::Friend")

    expect(resolve_ids(user:, query: "Best friend")).to contain_exactly(best_friend.id)
    expect(resolve_ids(user:, query: "In-law")).to contain_exactly(in_law.id)
  end

  it "searches relationship types by displayed Spanish labels" do
    user = create(:user)
    partner = create(:relationship_profile, user:, first_name: "Maya", type: "RelationshipProfiles::Partner")
    create(:relationship_profile, user:, first_name: "Rafa", type: "RelationshipProfiles::Friend")

    I18n.with_locale(:es) do
      expect(resolve_ids(user:, query: "Pareja")).to contain_exactly(partner.id)
    end
  end

  it "filters by reusable tag and relationship group assignments" do
    user = create(:user)
    tag = create(:relationship_tag, user:, name: "VIP")
    group = create(:relationship_group, user:, name: "college friends")
    visible = create(:relationship_profile, user:, first_name: "Maya")
    tag_only = create(:relationship_profile, user:, first_name: "Rafa")
    create(:relationship_tagging, relationship_profile: visible, relationship_tag: tag)
    create(:relationship_group_membership, relationship_profile: visible, relationship_group: group)
    create(:relationship_tagging, relationship_profile: tag_only, relationship_tag: tag)
    create(:relationship_profile, user:, first_name: "Nora")

    query = described_class.new(
      RelationshipProfile.where(user:),
      params: ActionController::Parameters.new(tag_id: tag.id, group_id: group.id)
    )

    expect(query.resolve.map(&:id)).to contain_exactly(visible.id)
    expect(query.tag_id).to eq(tag.id)
    expect(query.group_id).to eq(group.id)
  end

  it "searches relationship preferences without leaking profiles outside the provided scope" do
    user = create(:user)
    visible = create(:relationship_profile, user:, first_name: "Maya")
    hidden = create(:relationship_profile, first_name: "Nora")
    create(
      :relationship_preference,
      relationship_profile: visible,
      key: "Dinner setting",
      value: "Quiet restaurants",
      category: "social_settings",
      source_notes: "Mentioned after a crowded team dinner"
    )
    create(
      :relationship_preference,
      relationship_profile: hidden,
      key: "Dinner setting",
      value: "Quiet restaurants",
      category: "social_settings"
    )

    expect(resolve_ids(user:, query: "quiet restaurants")).to contain_exactly(visible.id)
    expect(resolve_ids(user:, query: "crowded team dinner")).to contain_exactly(visible.id)
    expect(resolve_ids(user:, query: "social settings")).to contain_exactly(visible.id)
  end

  it "searches relationship preferences by localized enum labels" do
    user = create(:user)
    visible = create(:relationship_profile, user:, first_name: "Maya")
    create(
      :relationship_preference,
      relationship_profile: visible,
      category: "social_settings",
      key: "Dinner setting",
      value: "Quiet restaurants"
    )

    I18n.with_locale(:es) do
      expect(resolve_ids(user:, query: "Entornos sociales")).to contain_exactly(visible.id)
    end
  end

  it "normalizes accepted filter UUIDs to canonical lowercase values" do
    user = create(:user)
    tag = create(:relationship_tag, user:, name: "VIP")
    group = create(:relationship_group, user:, name: "college friends")
    visible = create(:relationship_profile, user:, first_name: "Maya")
    create(:relationship_tagging, relationship_profile: visible, relationship_tag: tag)
    create(:relationship_group_membership, relationship_profile: visible, relationship_group: group)

    query = described_class.new(
      RelationshipProfile.where(user:),
      params: ActionController::Parameters.new(tag_id: tag.id.upcase, group_id: group.id.upcase)
    )

    expect(query.resolve.map(&:id)).to contain_exactly(visible.id)
    expect(query.tag_id).to eq(tag.id)
    expect(query.group_id).to eq(group.id)
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
