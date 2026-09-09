require "rails_helper"

RSpec.describe "Conversational gift care", type: :service do
  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:) }
  let(:conversation) { ConciergeConversation.create!(user:, relationship_profile: profile) }
  let(:turn) { conversation.turns.create!(request_key: SecureRandom.uuid, content: "Gift ideas for Ana", locale: "en", context: Concierge::Context.capture(user:, conversation:)) }
  let(:token) { turn.claim! }

  around { |example| Timecop.freeze(Time.zone.local(2026, 9, 8, 10)) { example.run } }

  def execute(name, arguments = {})
    Concierge::Execute.call(turn:, token:, name:, arguments:)
  end

  def allow_gift_ideas(mode: "allow_automatically")
    create(:automation_permission, user:, capability: "suggest_gifts", mode:)
    generation = 0
    allow_any_instance_of(GiftRecommendations::OpenAiGenerator).to receive(:generate) do |_generator, **arguments|
      generation += 1
      arguments.fetch(:count).times.map do |index|
        { "title" => "Book #{generation} #{index + 1}", "rationale" => "A thoughtful reading idea",
          "estimated_price_cents" => 2500, "vendor" => nil, "source_ids" => [ "profile:#{profile.id}" ] }
      end
    end
  end

  it "hides generated gift ideas after an uncited preference input is corrected" do
    preference = create(:relationship_preference, relationship_profile: profile, value: "Green tea")
    allow_gift_ideas
    result = execute("gift_ideas.generate", {})
    idea = profile.gift_recommendations.find(result.fetch("records").first.fetch("id"))
    expect(Concierge::GeneratedSources.visible?(idea, turn:)).to be(true)
    preference.update!(value: "Black tea")
    later = conversation.turns.create!(request_key: SecureRandom.uuid, content: "Show ideas", locale: "es",
      context: Concierge::Context.capture(user:, conversation:))
    expect(Concierge::GeneratedSources.visible?(idea, turn: later)).to be(false)
  end

  it "generates permitted ideas once, offers alternatives and saves an actual gift without purchasing" do
    allow_gift_ideas
    result = execute("gift_ideas.generate", { budget_cents: 5000, occasion: "Birthday", needed_by: "2026-10-01" })
    expect(result.fetch("records").size).to eq(3)
    recommendation = profile.gift_recommendations.where(status: "generated").first
    alternative = execute("gift_ideas.alternative", { id: recommendation.id })
    expect(alternative).to include("status" => "succeeded")
    expect(alternative.fetch("records").size).to eq(1)
    expect(recommendation.reload).to be_dismissed
    current = profile.gift_recommendations.find(alternative.fetch("records").sole.fetch("id"))
    execute("gift_ideas.save", { id: current.id })
    expect(current.reload).to be_saved
    expect(current.gift).to have_attributes(status: "idea", name: current.title)
    expect(ExternalProviderAction.count).to eq(0)
    expect(Concierge::History.sources_current?(turn)).to be(true)
  end

  it "retires generated gift references after an authorized input correction and permits new ideas" do
    preference = create(:relationship_preference, relationship_profile: profile, value: "Green tea")
    allow_gift_ideas
    originals = execute("gift_ideas.generate").fetch("records")
    correction = execute("preferences.update", { id: preference.id, value: "Coffee" })
    expect(correction.fetch("superseded", [])).to include(*originals.map { |record| record.slice("record_type", "id") })
    expect(Concierge::History.sources_current?(turn.reload)).to be(true)
    expect(execute("gift_ideas.generate", { occasion: "Lunch" })).to include("status" => "succeeded")
  end

  it "requires the exact requested gift-generation approval and rechecks permission in the job" do
    allow_gift_ideas(mode: "ask_every_time")
    expect(execute("gift_ideas.generate", { budget_cents: 5000 })).to include("status" => "awaiting_approval")
    expect(profile.gift_recommendations).to be_empty
    action = turn.actions.sole
    Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint)
    ConciergeActionJob.perform_now(action.id)
    expect(action.reload.state).to eq("succeeded")
    expect(profile.gift_recommendations.count).to eq(3)
  end

  it "saves a generated work gift into the selected work records without exposing personal gifts" do
    profile.update!(relationship_mode: "professional", professional_context: { "gifts_allowed" => "1", "boundaries" => "Office stationery only" })
    personal = create(:gift, relationship_profile: profile, name: "Personal present")
    create(:automation_permission, user:, capability: "suggest_gifts", mode: "allow_automatically")
    allow_any_instance_of(GiftRecommendations::OpenAiGenerator).to receive(:generate) do |_generator, **arguments|
      arguments.fetch(:count).times.map do |index|
        { "title" => "Notebook #{index}", "rationale" => "Office stationery within work boundaries",
          "estimated_price_cents" => 1000, "vendor" => nil, "source_ids" => [ "professional:boundaries" ] }
      end
    end
    generated = execute("gift_ideas.generate", { budget_cents: 2000 })
    id = generated.fetch("records").first.fetch("id")
    result = execute("gift_ideas.save", { id: })
    gift = profile.gift_recommendations.find(id).gift
    expect(profile.reload.work_context.selected("gifts").pluck(:id)).to eq([ gift.id ])
    expect(result.fetch("record")).to include("record_type" => "Gift", "id" => gift.id)
    expect(execute("gifts.search").fetch("records").pluck("id")).to eq([ gift.id ])
    expect(profile.work_context.selected("gifts").pluck(:id)).not_to include(personal.id)
    expect(Concierge::History.sources_current?(turn)).to be(true)
  end

  it "records a gift and its given outcome without resetting a completed gift to an idea" do
    result = execute("gifts.create", { name: "Book", price_cents: 2500, occasion: "Birthday" })
    gift = profile.gifts.find(result.fetch("record").fetch("id"))
    execute("gifts.mark_given", { id: gift.id, given_on: "2026-09-08", reaction: "Loved the story", outcome: "successful" })
    expect(gift.reload).to have_attributes(status: "given", given_on: Date.new(2026, 9, 8), outcome: "successful")
    expect { execute("gifts.update", { id: gift.id, status: "idea" }) }.to raise_error(Concierge::InvalidArguments)
  end

  it "keeps purchase preparation manual, bounded and versioned, with an existing-plan task" do
    gift = create(:gift, relationship_profile: profile)
    execute("gift_purchases.save", { gift_id: gift.id, version: "new", budget: "75.00", currency: "USD", purchase_by: "2026-09-20" })
    purchase = gift.reload.purchase_plan
    execute("gift_purchases.add_option", { gift_id: gift.id, version: purchase.lock_version.to_s, vendor: "Book shop", cost: "25.00", constraints_checked: true })
    expect(purchase.reload.options.sole).to include("vendor" => "Book shop", "cost" => "25.00", "constraints_checked" => "1")
    plan = create(:event_plan, user:, relationship_profile: profile)
    execute("gift_purchases.add_task", { gift_id: gift.id, event_plan_id: plan.id })
    expect(purchase.reload.current_plan_task).to have_attributes(event_plan: plan, due_on: Date.new(2026, 9, 20))
    expect(purchase.purchase_status).to eq("planning")
    expect(ExternalProviderAction.count).to eq(0)
  end

  it "builds a gift box with individually reviewed items and preserves whole-box version checks" do
    result = execute("gift_boxes.create", { name: "Birthday box", occasion: "Birthday", budget: "100.00", currency: "USD" })
    box = profile.gift_boxes.find(result.fetch("record").fetch("id"))
    result = execute("gift_boxes.add_item", { id: box.id, lock_version: box.lock_version, name: "Book", cost: "25.00" })
    item = box.reload.items.sole
    expect(box.known_total).to eq(BigDecimal("25.00"))
    execute("gift_boxes.update_item", { id: box.id, item_id: item.id, lock_version: box.lock_version, purchased: true, completed: true })
    expect(item.reload).to have_attributes(purchased: true, completed: true)
    expect(result.fetch("records").sole).to include("id" => item.id)
    expect(ExternalProviderAction.count).to eq(0)
  end

  it "never crosses ownership for a gift purchase plan or item" do
    gift = create(:gift)
    expect { execute("gift_purchases.read", { gift_id: gift.id }) }.to raise_error(ActiveRecord::RecordNotFound)
    box = profile.gift_boxes.create!(name: "Reading box", occasion: "Birthday")
    other_box = gift.relationship_profile.gift_boxes.create!(name: "Other box", occasion: "Birthday")
    item = other_box.items.create!(name: "Private item")
    expect do
      execute("gift_boxes.update_item", { id: box.id, item_id: item.id, lock_version: box.lock_version, name: "Foreign" })
    end.to raise_error(ActiveRecord::RecordNotFound)
    expect(item.reload.name).not_to eq("Foreign")
  end

  it "rejects stale purchase edits and a fourth option without changing the saved preparation" do
    gift = create(:gift, relationship_profile: profile)
    execute("gift_purchases.save", { gift_id: gift.id, version: "new", budget: "75.00" })
    purchase = gift.reload.purchase_plan
    3.times do |index|
      execute("gift_purchases.add_option", { gift_id: gift.id, version: purchase.reload.lock_version.to_s, vendor: "Shop #{index}" })
    end
    expect do
      execute("gift_purchases.add_option", { gift_id: gift.id, version: purchase.reload.lock_version.to_s, vendor: "Fourth" })
    end.to raise_error(ActiveRecord::RecordInvalid)
    expect do
      execute("gift_purchases.save", { gift_id: gift.id, version: "0", budget: "90.00" })
    end.to raise_error(Concierge::RequestConflict)
    expect(purchase.reload.budget).to eq(BigDecimal("75.00"))
    expect(purchase.options.size).to eq(3)
  end

  it "binds item removal to the reviewed box and keeps companion suggestions source backed" do
    preference = profile.relationship_preferences.create!(key: "Reading", value: "Books", confidence: "confirmed", preference_type: "positive")
    box = profile.gift_boxes.create!(name: "Reading box", occasion: "Birthday", budget: "50.00")
    item = box.items.create!(name: "Book", cost: "25.00")
    suggestions = execute("gift_boxes.suggest_companions", { id: box.id })
    expect(suggestions.fetch("suggestions").sole).to include("source_id" => preference.id, "certainty" => "suggested")
    result = execute("gift_boxes.remove_item", { id: box.id, item_id: item.id, lock_version: box.lock_version })
    expect(result).to include("status" => "awaiting_approval")
    expect(item.reload).to be_persisted
    action = turn.actions.find(result.fetch("action_id"))
    Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint)
    expect(box.items.reload).to be_empty
    expect(Concierge::History.sources_current?(turn)).to be(true)
  end

  it "creates only approved milestone reminders and preserves the owner's exact Spanish schedule" do
    create(:automation_permission, user:, capability: "send_reminders", mode: "ask_every_time")
    turn.update!(locale: "es")
    gift = create(:gift, relationship_profile: profile, name: "Libro")
    execute("gift_purchases.save", { gift_id: gift.id, version: "new", purchase_by: "2026-09-20" })
    result = execute("gift_purchases.remind", { gift_id: gift.id, milestone: "purchase", scheduled_at: "2026-09-20T09:00:00-06:00" })
    expect(result).to include("status" => "awaiting_approval")
    expect(user.reminders).to be_empty
    action = turn.actions.find(result.fetch("action_id"))
    2.times { Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint) }
    expect(user.reminders.sole).to have_attributes(reminder_type: "gift_planning", recurrence: "none", relationship_profile_id: profile.id,
      scheduled_at: Time.iso8601("2026-09-20T09:00:00-06:00"), title: I18n.t("gift_purchase_plans.reminder_titles.purchase", locale: :es, name: "Libro"))
  end

  it "sets a gift-box delivery reminder without copying item notes or changing delivery records" do
    create(:automation_permission, user:, capability: "send_reminders", mode: "allow_automatically")
    box = profile.gift_boxes.create!(name: "Reading box", occasion: "Birthday", delivery_on: "2026-09-20", notes: "Shipping details")
    execute("gift_boxes.remind", { id: box.id, scheduled_at: "2026-09-20T09:00:00-06:00" })
    expect(user.reminders.sole).to have_attributes(reminder_type: "gift_planning", notes: nil)
    expect(box.reload.delivery_on).to eq(Date.new(2026, 9, 20))
  end
end
