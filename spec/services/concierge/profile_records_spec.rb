require "rails_helper"

RSpec.describe "Concierge relationship records", type: :service do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:) }
  let(:conversation) { ConciergeConversation.create!(user:, relationship_profile: profile) }
  let(:turn) { conversation.turns.create!(request_key: SecureRandom.uuid, content: "Record our call", locale: "en", context: Concierge::Context.capture(user:, conversation:)) }
  let(:token) { turn.claim! }

  def execute(name, **arguments)
    Concierge::Execute.call(turn:, token:, name:, arguments: arguments.stringify_keys)
  end

  [ [ "commitments", :commitment, :due_on, Date.current ],
    [ "preferences", :relationship_preference, :learned_on, Date.current ],
    [ "gifts", :gift, :price_cents, 1000 ],
    [ "moods", :mood_note, :follow_up_at, 1.day.from_now ] ].each do |namespace, factory, field, value|
    it "clears the nullable #{namespace}.#{field} field explicitly" do
      record = create(factory, relationship_profile: profile, field => value)
      result = execute("#{namespace}.update", id: record.id, field => nil)
      expect(result.fetch("status")).to eq("succeeded")
      expect(record.reload.public_send(field)).to be_nil
      property = Concierge::Catalog.fetch("#{namespace}.update").schema.fetch(:properties).fetch(field.to_s)
      expect(property.fetch(:type)).to include("null")
    end
  end

  it "preserves omitted fields and rejects null for fields with domain defaults" do
    commitment = create(:commitment, relationship_profile: profile, due_on: Date.current)
    execute("commitments.update", id: commitment.id, title: "Corrected title")
    expect(commitment.reload.due_on).to eq(Date.current)
    desire = create(:desire, relationship_profile: profile, captured_on: Date.current)
    expect { execute("desires.update", id: desire.id, captured_on: nil) }.to raise_error(Concierge::InvalidArguments)
    expect(desire.reload.captured_on).to eq(Date.current)
    expect { Concierge::Catalog.fetch("commitments.update").validate("id" => nil) }.to raise_error(Concierge::InvalidArguments)
  end

  %w[selected authored].each do |kind|
    it "keeps #{kind} private-note history private after its note is deleted" do
      note = if kind == "selected"
        profile.relationship_notes.create!(body: "SECRET original fact", private: true).tap do |record|
          turn.update!(context: Concierge::Context.capture(user:, conversation:, selections: { "private_note_ids" => [ record.id ] }))
        end
      else
        result = execute("notes.create", body: "SECRET original fact", private: true)
        profile.relationship_notes.find(result.dig("record", "id"))
      end
      execute("notes.read", id: note.id)
      result = execute("notes.destroy", id: note.id)
      action = turn.actions.find(result.fetch("action_id"))
      Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint)
      turn.reload.finish!(token:, response: "SECRET original fact was removed")
      Timecop.travel(1.minute.from_now) do
        later = conversation.turns.create!(request_key: SecureRandom.uuid, content: "Continue", locale: "en",
          context: Concierge::Context.capture(user:, conversation:))
        expect(Concierge::History.messages(turn: later).to_json).not_to include("SECRET")
      end
    end
  end

  it "saves and corrects recaps with one synchronized interaction and timeline entry" do
    result = execute("recaps.create", title: "New job", body: "Ana starts on Monday", occurred_at: 1.hour.ago.iso8601)
    recap = profile.conversation_recaps.find(result.dig("record", "id"))
    expect(recap.timeline_entry).to have_attributes(body: recap.body, origin: "system")
    expect(recap.interaction).to have_attributes(origin: "derived", occurred_at: recap.occurred_at)
    execute("recaps.update", id: recap.id, body: "Ana starts on Tuesday")
    expect(recap.timeline_entry.reload.body).to eq("Ana starts on Tuesday")
    expect(profile.interactions.count).to eq(1)
    expect do
      execute("interactions.update", id: recap.interaction.id, notes: "Overwrite derived record")
    end.to raise_error(Pundit::NotAuthorizedError)
  end

  it "enqueues extraction once only when the user requests it and the feature permits it" do
    allow(FeatureFlag).to receive(:enabled?).with("ai_memory_extraction", user:, environment: Rails.env).and_return(true)
    arguments = { title: "Call", body: "Likes quiet places", occurred_at: 1.hour.ago.iso8601, request_memory_extraction: true }
    expect { execute("recaps.create", **arguments) }.to have_enqueued_job(MemoryExtractionJob).exactly(:once)
    expect { execute("recaps.create", **arguments) }.not_to have_enqueued_job(MemoryExtractionJob)
    expect(profile.conversation_recaps.sole.extraction_status).to eq("requested")
  end

  it "keeps recap content current after the requested extraction job completes but still detects edits" do
    allow(FeatureFlag).to receive(:enabled?).with("ai_memory_extraction", user:, environment: Rails.env).and_return(true)
    extractor = instance_double(MemoryExtractions::OpenAiExtractor, extract: [])
    allow(MemoryExtractions::OpenAiExtractor).to receive(:new).and_return(extractor)
    result = execute("recaps.create", title: "Call", body: "Likes quiet places", occurred_at: 1.hour.ago.iso8601, request_memory_extraction: true)
    recap = profile.conversation_recaps.find(result.dig("record", "id"))
    expect(Concierge::History.sources_current?(turn)).to be(true)
    approval = execute("recaps.destroy", id: recap.id)
    action = turn.actions.find(approval.fetch("action_id"))
    perform_enqueued_jobs(only: MemoryExtractionJob)
    expect do
      Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint)
    end.to raise_error(Concierge::RequestConflict)
    expect(recap.reload.extraction_status).to eq("completed")
    expect(Concierge::History.sources_current?(turn)).to be(true)
    recap.update!(body: "Corrected summary")
    expect(Concierge::History.sources_current?(turn)).to be(false)
  end

  it "rejects extraction when disabled without saving a partial recap" do
    allow(FeatureFlag).to receive(:enabled?).with("ai_memory_extraction", user:, environment: Rails.env).and_return(false)
    expect do
      execute("recaps.create", title: "Call", body: "Hello", occurred_at: 1.hour.ago.iso8601, request_memory_extraction: true)
    end.to raise_error(Concierge::PermissionDenied)
    expect(profile.conversation_recaps).to be_empty
  end

  it "keeps mood visibility and its derived interaction synchronized" do
    result = execute("moods.create", category: "proud", observation: "Finished the project", timeline_visible: true)
    mood = profile.mood_notes.find(result.dig("record", "id"))
    expect(mood.timeline_entry).to be_present
    expect(mood.interaction).to be_derived
    execute("moods.update", id: mood.id, timeline_visible: false)
    expect(mood.reload.timeline_entry).to be_nil
    expect(mood.interaction).to be_present
  end

  it "preserves commitment lifecycle and timeline evidence" do
    result = execute("commitments.create", title: "Call Dad", due_on: Date.current.iso8601)
    commitment = profile.commitments.find(result.dig("record", "id"))
    execute("commitments.complete", id: commitment.id)
    expect(commitment.reload.status).to eq("completed")
    expect(commitment.timeline_entry.title).to eq("Call Dad")
    execute("commitments.reopen", id: commitment.id)
    expect(commitment.reload.status).to eq("open")
  end

  it "records a desire fulfillment once and refuses bypassing its lifecycle" do
    result = execute("desires.create", title: "Visit the coast", category: "travel")
    desire = profile.desires.find(result.dig("record", "id"))
    execute("desires.fulfill", id: desire.id, fulfilled_on: Date.current.iso8601)
    execute("desires.fulfill", id: desire.id, fulfilled_on: Date.current.iso8601)
    expect(desire.reload.status).to eq("fulfilled")
    expect(desire.fulfillments.count).to eq(1)
    expect { execute("desires.update", id: desire.id, status: "active") }.to raise_error(Concierge::RequestConflict)
  end

  it "persists preferences, dates, and contact rhythm through the actual relationship records" do
    execute("preferences.create", key: "Restaurants", value: "Quiet", preference_type: "positive", confidence: "confirmed")
    expect(profile.reload.relationship_preferences.sole.value).to eq("Quiet")
    execute("dates.create", date_type: "birthday", starts_on: "2026-10-20", recurrence: "yearly")
    expect(profile.reload.important_dates.sole.starts_on).to eq(Date.new(2026, 10, 20))
    execute("cadence.save", interval_days: 14)
    execute("cadence.save", interval_days: 30)
    expect(profile.reload.contact_cadence.interval_days).to eq(30)
  end

  it "never searches private unselected notes or another owner's records" do
    profile.relationship_notes.create!(body: "Public café", private: false)
    profile.relationship_notes.create!(body: "Private hospital", private: true)
    records = execute("notes.search").fetch("records")
    expect(records.map { |record| record["body"] }).to eq([ "Public café" ])
    other = create(:relationship_profile)
    expect { execute("dates.search", relationship_profile_id: other.id) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "keeps an authorized correction of a selected private note current but rejects later edits" do
    note = profile.relationship_notes.create!(body: "Initial private detail", private: true)
    turn.update!(context: Concierge::Context.capture(user:, conversation:, selections: { "private_note_ids" => [ note.id ] }))
    execute("notes.read", id: note.id)
    execute("notes.update", id: note.id, body: "Corrected private detail")
    expect { Concierge::Respond.verify_response!(turn.reload) }.not_to raise_error
    expect(execute("notes.read", id: note.id).dig("record", "body")).to eq("Corrected private detail")
    note.update!(body: "Unrelated later change")
    expect { Concierge::Respond.verify_response!(turn.reload) }.to raise_error(Concierge::ContextUnavailable)
  end

  [ true, false ].each do |selected|
    it "keeps newly authored private notes usable only in their turn with selected person #{selected}" do
      conversation.update!(relationship_profile: nil) unless selected
      result = execute("notes.create", relationship_profile_id: profile.id, body: "New private detail", private: true)
      note = profile.relationship_notes.find(result.dig("record", "id"))
      expect { Concierge::Respond.verify_response!(turn.reload) }.not_to raise_error
      expect(execute("notes.read", relationship_profile_id: profile.id, id: note.id).dig("record", "body")).to eq("New private detail")
      turn.finish!(token:, response: "The new private detail was saved.")
      later = conversation.turns.create!(content: "Continue", request_key: SecureRandom.uuid, locale: "en",
        context: Concierge::Context.capture(user:, conversation:))
      expect(Concierge::History.messages(turn: later).to_json).not_to include("new private detail")
      expect do
        Concierge::Execute.call(turn: later, token: later.claim!, name: "notes.read", arguments: { relationship_profile_id: profile.id, id: note.id })
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  it "keeps selected-note context valid when an authorized edit makes the note public" do
    note = profile.relationship_notes.create!(body: "Initially private", private: true)
    turn.update!(context: Concierge::Context.capture(user:, conversation:, selections: { "private_note_ids" => [ note.id ] }))
    execute("notes.update", id: note.id, private: false)
    expect { Concierge::Respond.verify_response!(turn.reload) }.not_to raise_error
    expect(turn.context.fetch("private_note_ids")).not_to include(note.id)
  end

  it "clears a selected note dependency only after its deletion is explicitly approved" do
    note = profile.relationship_notes.create!(body: "Selected private detail", private: true)
    turn.update!(context: Concierge::Context.capture(user:, conversation:, selections: { "private_note_ids" => [ note.id ] }))
    result = execute("notes.destroy", id: note.id)
    expect(note.reload).to be_persisted
    action = turn.actions.find(result.fetch("action_id"))
    Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint)
    expect(RelationshipNote.exists?(note.id)).to be(false)
    expect { Concierge::Respond.verify_response!(turn.reload) }.not_to raise_error
  end

  it "bounds authored private-note access without leaving an orphaned seventh write" do
    6.times { |index| execute("notes.create", body: "Private detail #{index}", private: true) }
    expect { execute("notes.create", body: "Seventh private detail", private: true) }.to raise_error(Concierge::LimitReached)
    expect(profile.relationship_notes.count).to eq(6)
    expect { Concierge::Respond.verify_response!(turn.reload) }.not_to raise_error
  end

  it "finds manual and derived interactions by the notes displayed to the owner" do
    recap_result = execute("recaps.create", title: "Call", body: "Discussed the garden", occurred_at: 1.hour.ago.iso8601)
    mood_result = execute("moods.create", category: "proud", observation: "Proud of the garden", timeline_visible: true)
    manual_result = execute("interactions.create", interaction_type: "call", occurred_at: 1.hour.ago.iso8601, notes: "Called about the garden")
    recap = profile.conversation_recaps.find(recap_result.dig("record", "id"))
    mood = profile.mood_notes.find(mood_result.dig("record", "id"))
    expect(execute("interactions.search", query: "garden").fetch("records").pluck("id"))
      .to contain_exactly(recap.interaction.id, mood.interaction.id, manual_result.dig("record", "id"))
  end

  it "requires exact ISO dates and offset-bearing times rather than guessing" do
    expect { execute("dates.create", date_type: "birthday", starts_on: "next month") }.to raise_error(Concierge::InvalidArguments)
    expect { execute("interactions.create", interaction_type: "call", occurred_at: "2026-09-08 10:00") }.to raise_error(Concierge::InvalidArguments)
  end

  it "keeps previously read derived records current after correcting a recap" do
    created = execute("recaps.create", title: "New job", body: "Starts Monday", occurred_at: 1.hour.ago.iso8601)
    recap = profile.conversation_recaps.find(created.fetch("record").fetch("id"))
    execute("interactions.read", id: recap.interaction.id)
    execute("timeline.read", id: recap.timeline_entry.id)
    execute("recaps.update", id: recap.id, body: "Starts Tuesday")
    expect(recap.interaction.reload.display_notes).to eq("Starts Tuesday")
    expect(recap.timeline_entry.reload.body).to eq("Starts Tuesday")
    expect(Concierge::History.sources_current?(turn)).to be(true)
  end

  it "removes a recap and its previously read derived entries only after review" do
    created = execute("recaps.create", title: "Call", body: "A useful conversation", occurred_at: 1.hour.ago.iso8601)
    recap = profile.conversation_recaps.find(created.fetch("record").fetch("id"))
    execute("interactions.read", id: recap.interaction.id)
    execute("timeline.read", id: recap.timeline_entry.id)
    result = execute("recaps.destroy", id: recap.id)
    expect(profile.conversation_recaps).to exist
    action = turn.actions.find(result.fetch("action_id"))
    Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint)
    expect(profile.conversation_recaps).to be_empty
    expect(profile.interactions).to be_empty
    expect(profile.timeline_entries).to be_empty
    expect(Concierge::History.sources_current?(turn)).to be(true)
  end
end
