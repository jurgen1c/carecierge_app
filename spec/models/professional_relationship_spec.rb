require "rails_helper"

RSpec.describe "Professional relationship boundaries" do
  it "requires explicit classification and encrypts context separately from personal details" do
    profile = create(:relationship_profile, type: "RelationshipProfiles::Client")
    expect(profile).not_to be_professional
    profile.update!(relationship_mode: "professional", professional_context: { "organization" => "Private Company" })
    expect(profile.reload).to be_professional
    expect(profile.professional_context["organization"]).to eq("Private Company")
    expect(profile.read_attribute_before_type_cast(:professional_context)).not_to include("Private Company")
  end

  it "rejects unknown modes, oversized context, and foreign or protected work sources" do
    profile = create(:relationship_profile)
    foreign = create(:commitment)
    private_note = create(:relationship_note, relationship_profile: profile, private: true)
    profile.assign_attributes(relationship_mode: "invalid", professional_context: {
      "organization" => "x" * 1001, "commitments" => [ foreign.id ], "relationship_notes" => [ private_note.id ]
    })
    expect(profile).not_to be_valid
    expect(profile.errors[:relationship_mode]).to be_present
    expect(profile.errors[:professional_context]).to be_present
  end

  it "fences pending generations when classification or selected work context changes" do
    profile = create(:relationship_profile)
    expect { profile.update!(relationship_mode: "professional") }.to change { profile.reload.message_draft_generation_version }.by(1)
    expect { profile.update!(professional_context: { "boundaries" => "No gifts" }) }.to change { profile.reload.briefing_generation_version }.by(1)
  end
end

RSpec.describe "Professional gift boundaries" do
  it "requires recorded policy as well as suitability and withdraws permission when policy is cleared" do
    profile = create(:relationship_profile, relationship_mode: "professional", professional_context: { "gifts_allowed" => "1" })
    expect(profile).not_to be_professional_gifts_allowed
    profile.update!(professional_context: { "gifts_allowed" => "1", "boundaries" => "No gifts above twenty dollars" })
    expect(profile).to be_professional_gifts_allowed
    profile.update!(professional_context: { "gifts_allowed" => "1", "boundaries" => "" })
    expect(profile).not_to be_professional_gifts_allowed
  end
end
