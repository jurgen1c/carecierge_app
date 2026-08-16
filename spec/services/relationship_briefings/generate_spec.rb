require "rails_helper"

RSpec.describe RelationshipBriefings::Generate do
  it "makes every persisted source mutation take the profile lock used by final context reads" do
    profile = create(:relationship_profile)
    sources = [
      create(:timeline_entry, relationship_profile: profile),
      create(:commitment, relationship_profile: profile),
      create(:important_date, relationship_profile: profile),
      create(:relationship_preference, relationship_profile: profile),
      create(:relationship_note, relationship_profile: profile, body: "Existing note")
    ]
    profile_lock_sql = []
    subscriber = lambda do |*, payload|
      sql = payload.fetch(:sql)
      profile_lock_sql << sql if sql.include?('FROM "relationship_profiles"') && sql.include?("FOR UPDATE")
    end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      sources[0].update!(title: "Updated timeline")
      sources[1].update!(title: "Updated commitment")
      sources[2].update!(title: "Updated date")
      sources[3].update!(value: "Updated preference")
      sources[4].update!(body: "Updated note")
    end

    expect(profile_lock_sql.size).to be >= sources.size
  end

  it "creates an encrypted source-backed briefing and privacy-minimized audit evidence" do
    user = create(:user)
    profile = create(:relationship_profile, user:, preferred_name: "Maya")
    timeline = create(:timeline_entry, relationship_profile: profile, title: "Started a new role")
    generator = double
    expect(generator).to receive(:generate).with(
      interaction_context: "Dinner after work",
      sources: array_including(have_attributes(id: "timeline:#{timeline.id}")),
      locale: :en
    ).and_return([
      {
        "key" => "recent_activity",
        "items" => [
          {
            "body" => "Maya started a new role.",
            "certainty" => "confirmed",
            "source_ids" => [ "timeline:#{timeline.id}" ]
          }
        ]
      }
    ])

    briefing = described_class.call(
      actor: user,
      relationship_profile: profile,
      interaction_context: " Dinner after work ",
      locale: :en,
      generator:
    )

    expect(briefing).to have_attributes(
      user:,
      relationship_profile: profile,
      interaction_context: "Dinner after work",
      status: "generated",
      locale: "en"
    )
    expect(briefing.sections.dig(0, "items", 0, "sources", 0)).to include(
      "id" => "timeline:#{timeline.id}",
      "sensitive" => false
    )
    expect(AuditEvent.where(user:, action: "relationship_briefing.generated", target: profile)).to exist
  end

  it "downgrades provider certainty when any cited source is inferred" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    preference = create(:relationship_preference, relationship_profile: profile, confidence: "inferred")
    generator = double(generate: [
      {
        "key" => "conversation_topics",
        "items" => [
          {
            "body" => "Consider asking about quiet restaurants.",
            "certainty" => "confirmed",
            "source_ids" => [ "preference:#{preference.id}" ]
          }
        ]
      }
    ])

    briefing = described_class.call(
      actor: user,
      relationship_profile: profile,
      interaction_context: "Dinner",
      generator:
    )

    expect(briefing.sections.dig(0, "items", 0, "certainty")).to eq("inferred")
  end

  it "fails closed when the provider cites an unknown source" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    generator = double(generate: [
      {
        "key" => "recent_activity",
        "items" => [
          {
            "body" => "Invented claim",
            "certainty" => "confirmed",
            "source_ids" => [ "timeline:unknown" ]
          }
        ]
      }
    ])

    expect do
      described_class.call(
        actor: user,
        relationship_profile: profile,
        interaction_context: "Dinner",
        generator:
      )
    end.to raise_error(RelationshipBriefings::GenerationError, "Relationship briefing cited an unknown source")

    expect(profile.relationship_briefings).to be_empty
  end

  it "rejects vault context unless the active password-backed lease is revalidated" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    create(:privacy_vault_item, relationship_profile: profile)
    generator = double

    expect(generator).not_to receive(:generate)
    expect do
      described_class.call(
        actor: user,
        relationship_profile: profile,
        interaction_context: "Dinner",
        include_vault_context: true,
        generator:
      )
    end.to raise_error(RelationshipBriefings::VaultAccessError, "Privacy vault access is required")
  end

  it "does not persist output when source context changes during generation" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    timeline = create(:timeline_entry, relationship_profile: profile, title: "Original title")
    generator = double
    allow(generator).to receive(:generate) do
      timeline.update!(title: "Changed while generating")
      [
        {
          "key" => "recent_activity",
          "items" => [
            {
              "body" => "Original title",
              "certainty" => "confirmed",
              "source_ids" => [ "timeline:#{timeline.id}" ]
            }
          ]
        }
      ]
    end

    expect do
      described_class.call(
        actor: user,
        relationship_profile: profile,
        interaction_context: "Dinner",
        generator:
      )
    end.to raise_error(RelationshipBriefings::GenerationSupersededError)

    expect(profile.relationship_briefings).to be_empty
  end

  it "records sensitive access and replaces an unsaved generated briefing" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    private_note = create(:relationship_note, relationship_profile: profile, private: true, body: "Sensitive update")
    previous = create(:relationship_briefing, user:, relationship_profile: profile)
    generator = double(generate: [
      {
        "key" => "sensitive_context",
        "items" => [
          {
            "body" => "Be thoughtful about the update.",
            "certainty" => "confirmed",
            "source_ids" => [ "private_note:#{private_note.id}" ]
          }
        ]
      }
    ])

    briefing = described_class.call(
      actor: user,
      relationship_profile: profile,
      interaction_context: "Dinner",
      include_private_notes: true,
      generator:
    )

    expect(previous.reload).to be_dismissed
    expect(briefing.context_categories).to include("private_notes")
    expect(AuditEvent.where(user:, action: "sensitive_record.accessed", target: profile)).to exist
  end

  it "records sensitive access while holding the account and profile locks" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    private_note = create(:relationship_note, relationship_profile: profile, private: true, body: "Sensitive update")
    generator = double(generate: [
      {
        "key" => "sensitive_context",
        "items" => [
          {
            "body" => "Be thoughtful about the update.",
            "certainty" => "confirmed",
            "source_ids" => [ "private_note:#{private_note.id}" ]
          }
        ]
      }
    ])
    lock_scope = []
    sensitive_access_scope = nil
    allow(user).to receive(:with_lock).and_wrap_original do |method, *arguments, &block|
      lock_scope << :account
      method.call(*arguments, &block)
    ensure
      lock_scope.delete(:account)
    end
    allow(profile).to receive(:with_lock).and_wrap_original do |method, *arguments, &block|
      lock_scope << :profile
      method.call(*arguments, &block)
    ensure
      lock_scope.delete(:profile)
    end
    allow(AuditEvent).to receive(:record!).and_wrap_original do |method, **arguments|
      sensitive_access_scope = lock_scope.dup if arguments[:action] == "sensitive_record.accessed"
      method.call(**arguments)
    end

    described_class.call(
      actor: user,
      relationship_profile: profile,
      interaction_context: "Dinner",
      include_private_notes: true,
      generator:
    )

    expect(sensitive_access_scope).to eq(%i[account profile])
  end
end
