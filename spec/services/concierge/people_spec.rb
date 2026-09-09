require "rails_helper"

RSpec.describe "Conversational people management", type: :service do
  let(:user) { create(:user) }
  let(:conversation) { ConciergeConversation.create!(user:) }
  let(:turn) { conversation.turns.create!(request_key: SecureRandom.uuid, content: "Add Ana", locale: "en", context: Concierge::Context.capture(user:, conversation:)) }
  let(:token) { turn.claim! }

  def execute(name, arguments = {})
    Concierge::Execute.call(turn:, token:, name:, arguments:)
  end

  it "creates and corrects a person, then archives only after exact owner review" do
    result = execute("people.create", { first_name: "Ana", last_name: "Ruiz", birthday: "1990-05-10" })
    profile = user.relationship_profiles.find(result.fetch("record").fetch("id"))
    expect(profile).to have_attributes(first_name: "Ana", last_name: "Ruiz", birthday: Date.new(1990, 5, 10))
    expect(execute("people.create", { first_name: "Ana", last_name: "Ruiz", birthday: "1990-05-10" })).to eq(result)
    expect(user.relationship_profiles.count).to eq(1)
    execute("people.update", { id: profile.id, preferred_name: "Anita" })
    expect(execute("people.read", { id: profile.id }).fetch("record")).to include("title" => profile.reload.display_name)
    proposed = execute("people.archive", { id: profile.id })
    expect(profile.reload).not_to be_archived
    action = turn.actions.find(proposed.fetch("action_id"))
    Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint)
    expect(profile.reload).to be_archived
    expect(action.reload.state).to eq("succeeded")
  end

  it "refuses invalid birthdays and foreign updates without changing records" do
    other = create(:relationship_profile, first_name: "Other")
    expect { execute("people.create", { first_name: "Ana", birthday: "not a date" }) }.to raise_error(Concierge::InvalidArguments)
    expect { execute("people.update", { id: other.id, first_name: "Changed" }) }.to raise_error(ActiveRecord::RecordNotFound)
    expect(other.reload.first_name).to eq("Other")
    expect(user.relationship_profiles).to be_empty
  end

  it "creates a new work relationship in a professional conversation and excludes personal birthday input" do
    current = create(:relationship_profile, user:, relationship_mode: "professional")
    conversation.update!(relationship_profile: current)
    result = execute("people.create", { first_name: "Alex" })
    created = user.relationship_profiles.find(result.fetch("record").fetch("id"))
    expect(created).to be_professional
    expect(result.fetch("record")).not_to have_key("birthday")
    expect { execute("people.create", { first_name: "Sam", birthday: "1990-05-10" }) }.to raise_error(Concierge::ContextUnavailable)
    expect(user.relationship_profiles.count).to eq(2)
  end
end
