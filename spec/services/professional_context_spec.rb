require "rails_helper"

RSpec.describe "Professional generation context" do
  let(:profile) { create(:relationship_profile, relationship_mode: "professional") }

  it "uses explicitly selected live work sources and excludes all unselected personal and sensitive sources" do
    work_note = create(:relationship_note, relationship_profile: profile, body: "Meeting: send the proposal")
    work_preference = create(:relationship_preference, relationship_profile: profile, key: "Work channel", value: "Email before noon")
    commitment = create(:commitment, relationship_profile: profile, title: "Send proposal", due_on: Date.current + 1)
    milestone = create(:important_date, relationship_profile: profile, title: "Client launch", starts_on: Date.current + 3)
    create(:relationship_note, relationship_profile: profile, body: "Personal honeymoon")
    create(:relationship_note, relationship_profile: profile, private: true, body: "Private diagnosis")
    create(:privacy_vault_item, relationship_profile: profile, payload: { "title" => "Secret", "body" => "Vault secret" })
    profile.update!(professional_context: {
      "organization" => "Acme", "review_preparation" => "Discuss delivery goals", "boundaries" => "No personal topics",
      "relationship_notes" => [ work_note.id ], "relationship_preferences" => [ work_preference.id ],
      "commitments" => [ commitment.id ], "important_dates" => [ milestone.id ]
    })
    draft = MessageDrafts::ContextBuilder.new(relationship_profile: profile, include_private_notes: true, include_vault_context: true).call
    briefing = RelationshipBriefings::ContextBuilder.new(relationship_profile: profile, include_private_notes: true, include_vault_context: true).call
    [ draft.text, briefing.sources.map(&:content).join(" ") ].each do |content|
      expect(content).to include("Acme", "delivery goals", "send the proposal", "Email before noon", "Send proposal", "Client launch")
      expect(content).not_to include("honeymoon", "diagnosis", "Vault secret")
    end
    profile.update!(relationship_mode: "personal")
    expect(MessageDrafts::ContextBuilder.new(relationship_profile: profile).call.text).not_to include("Acme", "delivery goals")
  end

  it "revalidates selected notes after vault protection" do
    note = create(:relationship_note, relationship_profile: profile, body: "Work secret")
    profile.update!(professional_context: { "relationship_notes" => [ note.id ] })
    create(:privacy_vault_item, relationship_profile: profile, protectable: note, payload: { "title" => "Work", "body" => "Work secret" })
    expect(MessageDrafts::ContextBuilder.new(relationship_profile: profile).call.text).not_to include("Work secret")
  end

  it "suppresses intimacy suggestions and makes follow-up suggestions from selected commitments" do
    commitment = create(:commitment, relationship_profile: profile, title: "Work follow-up", due_on: Date.current - 1)
    create(:commitment, relationship_profile: profile, title: "Personal promise", due_on: Date.current - 3)
    profile.update!(professional_context: { "commitments" => [ commitment.id ] })
    suggestions = Suggestions::ForProfile.call(relationship_profile: profile)
    expect(suggestions.map(&:suggestion_type)).to eq([ "professional_follow_up" ])
    expect(suggestions.first.reasons.first.evidence).to eq("Work follow-up")
  end
end

RSpec.describe "Professional generation lifecycle" do
  let(:profile) { create(:relationship_profile, relationship_mode: "professional") }

  it "enforces professional tone even for a forged romantic selection" do
    generator = double
    expect(generator).to receive(:generate).with(hash_including(tone: "professional")).and_return("Following up on our meeting.")
    revision = MessageDrafts::Generate.call(expected_relationship_mode: "professional", actor: profile.user, relationship_profile: profile,
      draft_type: "professional_follow_up", tone: "romantic", generator:)
    expect(revision.context_categories).to include("professional")
  end

  %w[edit delete protect mode].each do |mutation|
    it "rejects a professional draft after selected source #{mutation} during generation" do
      note = create(:relationship_note, relationship_profile: profile, body: "Original meeting")
      profile.update!(professional_context: { "relationship_notes" => [ note.id ] })
      generator = double
      allow(generator).to receive(:generate) do
        case mutation
        when "edit" then note.update!(body: "Updated meeting")
        when "delete" then note.destroy!
        when "protect" then create(:privacy_vault_item, relationship_profile: profile, protectable: note, payload: { "title" => "Meeting", "body" => "Original meeting" })
        when "mode" then profile.update!(relationship_mode: "personal")
        end
        "Stale work suggestion"
      end
      expect do
        MessageDrafts::Generate.call(expected_relationship_mode: "professional", actor: profile.user, relationship_profile: profile,
          draft_type: "professional_follow_up", tone: "professional", generator:)
      end.to raise_error(MessageDrafts::GenerationSupersededError)
      expect(DraftRevision.count).to eq(0)
    end
  end

  it "blocks professional gift generation until suitability is explicitly confirmed" do
    generator = double
    expect(generator).not_to receive(:generate)
    expect do
      GiftRecommendations::Generate.call(actor: profile.user, relationship_profile: profile, generator:)
    end.to raise_error(GiftRecommendations::GenerationError)
  end

  it "limits gift and event provider contexts to selected work records" do
    note = create(:relationship_note, relationship_profile: profile, body: "Work conference")
    create(:relationship_note, relationship_profile: profile, body: "Personal anniversary")
    profile.update!(professional_context: { "relationship_notes" => [ note.id ], "gifts_allowed" => "1" })
    plan = create(:event_plan, relationship_profile: profile, user: profile.user)
    contexts = [ GiftRecommendations::ContextBuilder.new(relationship_profile: profile).call,
      EventPlans::ContextBuilder.new(event_plan: plan).call ]
    contexts.each do |context|
      expect(context.sources.map(&:content).join).to include("Work conference")
      expect(context.sources.map(&:content).join).not_to include("Personal anniversary")
    end
  end
end

RSpec.describe "Professional milestones and retained guidance" do
  it "uses the next local occurrence of selected recurring client milestones" do
    Timecop.freeze(Time.utc(2026, 9, 6, 1)) do
      profile = create(:relationship_profile, relationship_mode: "professional")
      create(:notification_preference, user: profile.user, time_zone: "America/Costa_Rica")
      date = create(:important_date, relationship_profile: profile, title: "Client anniversary", starts_on: Date.new(2020, 9, 5), recurrence: "yearly")
      profile.update!(professional_context: { "important_dates" => [ date.id ] })
      content = profile.work_context.entries.find { |entry| entry.id == "important_date:#{date.id}" }.content
      expect(content).to include("2026-09-05")
      expect(content).not_to include("2020-09-05")
    end
  end

  it "keeps a personal generated briefing when generating professional guidance" do
    profile = create(:relationship_profile, relationship_mode: "professional", professional_context: { "organization" => "Acme" })
    personal = create(:relationship_briefing, relationship_profile: profile, user: profile.user)
    generator = double(generate: [ { "key" => "recent_activity", "items" => [ { "body" => "Prepare for Acme", "certainty" => "confirmed", "source_ids" => [ "professional:organization" ] } ] } ])
    work = RelationshipBriefings::Generate.call(actor: profile.user, relationship_profile: profile, interaction_context: "Work meeting", generator:)
    expect(work).to be_generated
    expect(personal.reload).to be_generated
  end

  it "keeps personal gift ideas when generating professional ideas" do
    profile = create(:relationship_profile, relationship_mode: "professional", professional_context: { "gifts_allowed" => "1", "boundaries" => "Office stationery only" })
    create(:automation_permission, user: profile.user, capability: "suggest_gifts", mode: "allow_automatically")
    personal = create(:gift_recommendation, relationship_profile: profile, user: profile.user)
    generator = double(generate: [ { "title" => "Office notebook", "rationale" => "Appropriate stationery", "estimated_price_cents" => 1000, "vendor" => nil, "source_ids" => [ "professional:boundaries" ] } ])
    ideas = GiftRecommendations::Generate.call(actor: profile.user, relationship_profile: profile, generator:)
    expect(ideas.sole.relationship_mode).to eq("professional")
    expect(personal.reload).to be_generated
  end
end
