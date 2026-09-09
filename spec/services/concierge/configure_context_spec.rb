require "rails_helper"

RSpec.describe Concierge::ConfigureContext, type: :service do
  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:) }
  let(:conversation) { ConciergeConversation.create!(user:, relationship_profile: profile) }

  def configure(attributes, expected_version: Concierge::RecordVersion.for(profile))
    described_class.call(user:, conversation:, attributes:, expected_version:)
  end

  it "switches to explicitly selected work context in a fresh conversation and invalidates an unstarted old request" do
    note = profile.relationship_notes.create!(category: "Work", body: "Meeting agenda", private: false)
    private_note = profile.relationship_notes.create!(category: "Private", body: "Private detail", private: true)
    turn = conversation.turns.create!(request_key: SecureRandom.uuid, content: "Personal detail", locale: "en", context: Concierge::Context.capture(user:, conversation:))
    updated = configure({ relationship_mode: "professional", professional_context: { relationship_notes: [ note.id ], organization: "Studio" } })
    expect(updated).not_to eq(conversation)
    expect(updated.relationship_profile_id).to eq(profile.id)
    expect(updated.turns).to be_empty
    expect(profile.reload).to be_professional
    expect(profile.work_context.selected("relationship_notes").pluck(:id)).to eq([ note.id ])
    expect(profile.professional_context.to_json).not_to include(private_note.id)
    expect { Concierge::Context.verify!(turn:) }.to raise_error(Concierge::ContextUnavailable)
    expect(conversation.reload.turns.sole.content).to eq("Personal detail")
  end

  it "invalidates a captured professional request when its selection changes before its first tool" do
    profile.update!(relationship_mode: "professional")
    turn = conversation.turns.create!(request_key: SecureRandom.uuid, content: "Work follow-up", locale: "en", context: Concierge::Context.capture(user:, conversation:))
    configure({ professional_context: { organization: "New studio" } })
    expect { Concierge::Context.verify!(turn:) }.to raise_error(Concierge::ContextUnavailable)
  end

  it "keeps the same conversation for an unchanged save and refuses replay of an old form version" do
    version = Concierge::RecordVersion.for(profile)
    expect(configure({ relationship_mode: "personal" }, expected_version: version)).to eq(conversation)
    configure({ relationship_mode: "professional" }, expected_version: version)
    expect { configure({ relationship_mode: "professional" }, expected_version: version) }.to raise_error(Concierge::RequestConflict)
    expect(user.concierge_conversations.count).to eq(2)
  end

  it "rejects private and foreign work sources atomically" do
    private_note = profile.relationship_notes.create!(category: "Private", body: "Secret", private: true)
    foreign_note = create(:relationship_note, private: false)
    [ private_note, foreign_note ].each do |note|
      expect do
        configure({ relationship_mode: "professional", professional_context: { relationship_notes: [ note.id ] } })
      end.to raise_error(ActiveRecord::RecordInvalid)
      expect(profile.reload).not_to be_professional
      expect(user.concierge_conversations.count).to eq(1)
    end
  end

  it "rejects foreign conversations and archived relationships" do
    foreign = ConciergeConversation.create!(user: create(:user))
    expect do
      described_class.call(user:, conversation: foreign, attributes: {}, expected_version: "")
    end.to raise_error(Pundit::NotAuthorizedError)
    conversation
    profile.archive!
    expect { configure({}) }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
