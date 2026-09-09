require "rails_helper"

RSpec.describe "Conversational relationship suggestions", type: :service do
  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:) }
  let(:conversation) { ConciergeConversation.create!(user:, relationship_profile: profile) }
  let(:turn) { conversation.turns.create!(request_key: SecureRandom.uuid, content: "Suggest a thoughtful gesture", locale: "en", context: Concierge::Context.capture(user:, conversation:)) }
  let(:token) { turn.claim! }

  def execute(name, **arguments)
    Concierge::Execute.call(turn:, token:, name:, arguments:)
  end

  def gesture
    execute("ideas.search").fetch("records").find { |record| record["suggestion_type"] == "spontaneous" }
  end

  it "lists source-backed suggestions and records save, feedback and completion once" do
    idea = gesture
    expect(idea).to include("certainty" => "inferred", "source_certainty" => "confirmed")
    expect(idea.fetch("sources").sole).to include("id" => profile.id)
    execute("ideas.save", fingerprint: idea.fetch("id"))
    execute("ideas.feedback", fingerprint: idea.fetch("id"), feedback: "helpful")
    result = execute("ideas.complete", fingerprint: idea.fetch("id"))
    feedback = user.suggestion_feedbacks.sole
    expect(feedback).to be_saved_for_later
    expect(feedback.acted_at).to be_present
    expect(feedback.feedback).to eq("helpful")
    expect(execute("ideas.complete", fingerprint: idea.fetch("id"))).to eq(result)
    expect(execute("ideas.search").fetch("records")).to be_empty
    expect(Concierge::History.sources_current?(turn)).to be(true)
  end

  it "offers another gesture and excludes dismissed alternatives" do
    first = gesture
    profile.relationship_preferences.create!(category: "food", key: "Place", value: "Quiet garden", preference_type: "positive", confidence: "confirmed")
    alternative = execute("ideas.alternative", fingerprint: first.fetch("id")).fetch("record")
    expect(alternative).to include("variation" => "medium")
    expect(alternative.fetch("sources").sole).to include("record_type" => "RelationshipPreference")
    execute("ideas.dismiss", fingerprint: alternative.fetch("id"), variation: "medium")
    next_idea = execute("ideas.alternative", fingerprint: first.fetch("id")).fetch("record")
    expect(next_idea).to include("variation" => "high")
  end

  it "retires a suggestion after completing its source commitment without ignoring unrelated changes" do
    Timecop.freeze do
      commitment = create(:commitment, relationship_profile: profile, due_on: Date.current - 2)
      preference = create(:relationship_preference, relationship_profile: profile, value: "Email")
      profile.update!(relationship_mode: "professional", professional_context: { "commitments" => [ commitment.id ], "relationship_preferences" => [ preference.id ] })
      execute("preferences.read", id: preference.id)
      idea = execute("ideas.search").fetch("records").find do |record|
        record.fetch("sources").any? { |source| source["id"] == commitment.id }
      end
      expect(idea).to be_present
      result = execute("commitments.complete", id: commitment.id)
      expect(result.fetch("superseded", [])).to include(idea.slice("record_type", "id"))
      expect(Concierge::History.sources_current?(turn.reload)).to be(true)
      preference.update!(value: "An unrelated external correction")
      expect(Concierge::History.sources_current?(turn.reload)).to be(false)
    end
  end

  it "creates an explicitly timed reminder only after required approval and preserves suggestion state" do
    Timecop.freeze do
      user.automation_permissions.create!(relationship_profile: profile, capability: "send_reminders", mode: "ask_every_time")
      idea = gesture
      result = execute("ideas.remind", fingerprint: idea.fetch("id"), scheduled_at: 2.days.from_now.iso8601)
      expect(result).to include("status" => "awaiting_approval")
      expect(user.reminders).to be_empty
      action = turn.actions.find(result.fetch("action_id"))
      Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint)
      expect(user.reminders.sole.title).to eq(idea.fetch("title"))
      expect(user.suggestion_feedbacks.sole.acted_at).to be_present
      expect(Concierge::History.sources_current?(turn.reload)).to be(true)
      Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint)
      expect(user.reminders.count).to eq(1)
    end
  end

  it "keeps a Spanish reminder approval valid and executes in Spanish after the request switches to English" do
    Timecop.freeze do
      turn.update!(locale: "es")
      user.automation_permissions.create!(relationship_profile: profile, capability: "send_reminders", mode: "ask_every_time")
      idea, result = I18n.with_locale(:es) do
        idea = gesture
        [ idea, execute("ideas.remind", fingerprint: idea.fetch("id"), scheduled_at: 2.days.from_now.iso8601) ]
      end
      action = turn.actions.find(result.fetch("action_id"))
      I18n.with_locale(:en) do
        expect(Concierge::Decide.available?(user:, action:)).to be(true)
        Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint)
        expect(I18n.locale).to eq(:en)
      end
      expect(user.reminders.sole.title).to eq(idea.fetch("title"))
      expect(Concierge::History.sources_current?(turn.reload)).to be(true)
    end
  end

  it "keeps a same-day event suggestion and its approval current across request time zones" do
    Timecop.freeze(Time.utc(2026, 9, 9, 2)) do
      user.create_notification_preference!(time_zone: "America/Costa_Rica")
      turn.update!(locale: "es")
      create(:important_date, relationship_profile: profile, starts_on: Date.new(2026, 9, 8), recurrence: "none")
      user.automation_permissions.create!(relationship_profile: profile, capability: "send_reminders", mode: "ask_every_time")
      result = I18n.with_locale(:es) do
        Time.use_zone("America/Costa_Rica") do
          idea = execute("ideas.search").fetch("records").find { |record| record["suggestion_type"] == "event" }
          expect(idea).to be_present
          execute("ideas.remind", fingerprint: idea.fetch("id"), scheduled_at: 2.days.from_now.iso8601)
        end
      end
      action = turn.actions.find(result.fetch("action_id"))
      Time.use_zone("UTC") do
        expect(Concierge::History.sources_current?(turn)).to be(true)
        expect(Concierge::Decide.available?(user:, action:)).to be(true)
        Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint)
        expect(user.reminders.count).to eq(1)
        expect(Time.zone.name).to eq("UTC")
      end
      Timecop.travel(6.hours.from_now) do
        expect(Concierge::History.sources_current?(turn.reload)).to be(false)
      end
    end
  end

  it "rechecks the source content before an approved reminder can be saved" do
    Timecop.freeze do
      preference = profile.relationship_preferences.create!(category: "food", key: "Place", value: "Garden", preference_type: "positive", confidence: "confirmed")
      user.automation_permissions.create!(relationship_profile: profile, capability: "send_reminders", mode: "ask_every_time")
      idea = execute("ideas.search", variation: "medium").fetch("records").find { |record| record["suggestion_type"] == "spontaneous" }
      result = execute("ideas.remind", fingerprint: idea.fetch("id"), variation: "medium", scheduled_at: 2.days.from_now.iso8601)
      preference.update!(value: "Indoor seating")
      action = turn.actions.find(result.fetch("action_id"))
      expect { Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint) }.to raise_error(Concierge::RequestConflict)
      expect(user.reminders).to be_empty
      expect(Concierge::History.sources_current?(turn)).to be(false)
    end
  end

  it "rejects foreign fingerprints and unselected work sources" do
    other = create(:relationship_profile)
    foreign = Suggestions::ForProfile.call(relationship_profile: other).find(&:gesture?)
    expect { execute("ideas.save", fingerprint: foreign.fingerprint) }.to raise_error(ActiveRecord::RecordNotFound)
    profile.update!(relationship_mode: "professional", professional_context: { "role" => "Colleague" })
    profile.commitments.create!(title: "Personal promise", due_on: Date.current - 2)
    turn.update!(context: Concierge::Context.capture(user:, conversation:))
    expect(execute("ideas.search").fetch("records")).to be_empty
    expect(user.suggestion_feedbacks).to be_empty
  end

  it "schedules a selected work follow-up and keeps its reminder available in work chat" do
    Timecop.freeze do
      commitment = profile.commitments.create!(title: "Send the project notes", due_on: Date.current - 2)
      profile.update!(relationship_mode: "professional", professional_context: { "commitments" => [ commitment.id ] })
      user.automation_permissions.create!(relationship_profile: profile, capability: "send_reminders", mode: "allow_automatically")
      idea = execute("ideas.search").fetch("records").sole
      result = execute("ideas.remind", fingerprint: idea.fetch("id"), scheduled_at: 2.days.from_now.iso8601)
      reminder = user.reminders.find(result.fetch("record").fetch("id"))
      expect(reminder.commitment_id).to eq(commitment.id)
      expect(profile.reload.work_context.selected("reminders").pluck(:id)).to eq([ reminder.id ])
      expect(Concierge::History.sources_current?(turn)).to be(true)
    end
  end

  it "withdraws social-context evidence immediately when downstream use is revoked" do
    note = create(:social_context_note, relationship_profile: profile, body: "A garden conversation", allow_suggestions: true,
      interpretation: "Try a garden conversation", interpretation_status: "approved", suggested_uses: [ "conversation_topic" ])
    idea = execute("ideas.search").fetch("records").find { |record| record["suggestion_type"] == "conversation_topic" }
    expect(idea.fetch("sources").sole).to include("id" => note.id, "certainty" => "inferred")
    note.update_from_user!({ allow_suggestions: false })
    expect(Concierge::History.source_current?(idea, user:, turn:)).to be(false)
    expect { execute("ideas.feedback", fingerprint: idea.fetch("id"), feedback: "helpful") }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
