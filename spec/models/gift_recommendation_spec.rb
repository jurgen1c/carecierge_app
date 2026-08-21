require "rails_helper"

RSpec.describe GiftRecommendation, type: :model do
  it "encrypts generated content and source context at rest" do
    recommendation = create(
      :gift_recommendation,
      title: "Private pottery workshop",
      rationale: "A private note says they want to learn pottery.",
      vendor: "Neighborhood studio",
      source_context: [
        {
          "id" => "private_note:#{SecureRandom.uuid}",
          "label" => "Private note",
          "certainty" => "confirmed",
          "sensitive" => true
        }
      ]
    )

    raw = ApplicationRecord.connection.select_one(
      ApplicationRecord.sanitize_sql_array([
        "SELECT title, rationale, vendor, source_context FROM gift_recommendations WHERE id = ?",
        recommendation.id
      ])
    )

    expect(raw.values.join(" ")).not_to include("Private pottery", "private note says", "Neighborhood studio")
    expect(recommendation.reload.title).to eq("Private pottery workshop")
    expect(recommendation.source_context.sole.fetch("sensitive")).to be(true)
  end

  it "rejects cross-account ownership and malformed source evidence" do
    recommendation = build(
      :gift_recommendation,
      user: create(:user),
      relationship_profile: create(:relationship_profile),
      source_context: []
    )

    expect(recommendation).not_to be_valid
    expect(recommendation.errors.of_kind?(:relationship_profile, :owner_mismatch)).to be(true)
    expect(recommendation.errors.of_kind?(:source_context, :invalid)).to be(true)
  end

  it "returns only source IDs from structured evidence" do
    recommendation = build(
      :gift_recommendation,
      source_context: [
        { "id" => "profile:known" },
        "unstructured"
      ]
    )

    expect(recommendation.source_ids).to eq([ "profile:known" ])
  end

  it "rejects needed-by dates beyond the supported persistence range" do
    recommendation = build(:gift_recommendation, needed_by: GiftRecommendation::MAX_NEEDED_BY.next_day)

    expect(recommendation).not_to be_valid
    expect(recommendation.errors.of_kind?(:needed_by, :less_than_or_equal_to)).to be(true)
  end
end
