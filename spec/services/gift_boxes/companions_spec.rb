require "rails_helper"
RSpec.describe GiftBoxes::Companions do
  let(:profile) { create(:relationship_profile) }
  let(:box) { GiftBox.new(relationship_profile: profile, name: "Books", occasion: "Birthday", budget: 30) }
  it "uses confirmed preferences and avoids existing companion items" do
    preference = create(:relationship_preference, relationship_profile: profile, key: "Reading", value: "Books", preference_type: "positive", confidence: "confirmed")
    ideas = described_class.new(box).call
    expect(ideas.map { |idea| idea[:key] }).to include("bookmark")
    expect(ideas.first[:source]).to eq(preference)
    box.items.build(name: "Bookmark")
    expect(described_class.new(box).call.map { |idea| idea[:key] }).not_to include("bookmark")
  end
  it "withholds suggestions for unknown constraints, negative preferences, or exhausted budgets" do
    create(:relationship_preference, relationship_profile: profile, key: "Reading", value: "Books", preference_type: "positive", confidence: "confirmed")
    box.constraints = "No paper"
    expect(described_class.new(box).call).to be_empty
    box.constraints = nil
    create(:relationship_preference, relationship_profile: profile, key: "Materials", value: "No paper", preference_type: "constraint")
    expect(described_class.new(box).call).to be_empty
    profile.relationship_preferences.reload.destroy_all
    create(:relationship_preference, relationship_profile: profile, key: "Reading", value: "Books", preference_type: "positive", confidence: "inferred")
    expect(described_class.new(box).call).to be_empty
  end
end
