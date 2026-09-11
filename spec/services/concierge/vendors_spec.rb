require "rails_helper"

RSpec.describe "Conversational manual vendor and booking records", type: :service do
  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:) }
  let(:plan) { create(:event_plan, user:, relationship_profile: profile) }
  let(:conversation) { ConciergeConversation.create!(user:, relationship_profile: profile) }
  let(:turn) { conversation.turns.create!(request_key: SecureRandom.uuid, content: "Organize the dinner", locale: "en", context: Concierge::Context.capture(user:, conversation:)) }
  let(:token) { turn.claim! }

  def execute(name, arguments = {})
    Concierge::Execute.call(turn:, token:, name:, arguments:)
  end

  context "with committed availability transactions" do
    self.use_transactional_tests = false

    after { user.destroy! }

    it "holds the owner lock before every profile lock while checking vendor-option deletion approval" do
      result = execute("shortlists.create", { title: "Dinner options", vendor_ids: create_list(:vendor, 2, user:).map(&:id) })
      shortlist = user.vendor_shortlists.sole
      option = shortlist.vendor_options.first
      execute("vendor_options.destroy", { shortlist_id: shortlist.id, id: option.id })
      action = turn.actions.find_by!(name: "vendor_options.destroy")
      expect(result).to include("status" => "succeeded")
      owner_locked = false
      violations = []
      observer = lambda do |*, payload|
        sql = payload[:sql]
        owner_locked = false if sql.match?(/\A(?:BEGIN|COMMIT|ROLLBACK)\b/)
        if sql.include?('FROM "users"') && sql.match?(/FOR (?:NO KEY )?UPDATE/)
          owner_locked = true
        elsif sql.include?('FROM "relationship_profiles"') && sql.match?(/FOR (?:NO KEY )?UPDATE/)
          violations << sql unless owner_locked
        end
      end
      ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
        expect(Concierge::Decide.available?(user:, action:)).to be(true)
      end
      expect(violations).to be_empty
    end
  end

  it "creates, searches, edits and attaches a real owner vendor without contacting anyone" do
    result = execute("vendors.create", { name: "Casa Verde", category: "restaurant", minimum_price_cents: 5000 })
    vendor = user.vendors.sole
    expect(result.fetch("record")).to include("id" => vendor.id, "manual_record" => true)
    expect(execute("vendors.search", { query: "Verde" }).fetch("records").sole.fetch("id")).to eq(vendor.id)
    execute("vendors.update", { id: vendor.id, location: "San José" })
    execute("vendors.attach", { id: vendor.id, event_plan_id: plan.id })
    expect(plan.vendors.sole).to eq(vendor)
    execute("vendors.detach", { id: vendor.id, event_plan_id: plan.id })
    expect(plan.reload.vendors).to be_empty
    expect(vendor.reload.location).to eq("San José")
    expect(ExternalProviderAction.count).to eq(0)
  end

  it "compares owned vendors, applies decisions, and rejects stale detail edits" do
    vendors = create_list(:vendor, 2, user:)
    result = execute("shortlists.create", { title: "Dinner options", event_plan_id: plan.id, vendor_ids: vendors.map(&:id) })
    shortlist = user.vendor_shortlists.sole
    expect(result.fetch("records").size).to eq(2)
    first, second = shortlist.vendor_options.ordered.to_a
    execute("vendor_options.select", { shortlist_id: shortlist.id, id: first.id })
    execute("vendor_options.select", { shortlist_id: shortlist.id, id: second.id })
    expect(first.reload).to be_considering
    expect(second.reload).to be_selected
    version = second.lock_version
    execute("vendor_options.update", { shortlist_id: shortlist.id, id: second.id, lock_version: version, notes: "Quiet room" })
    expect(second.reload.notes).to eq("Quiet room")
    expect do
      execute("vendor_options.update", { shortlist_id: shortlist.id, id: second.id, lock_version: version, notes: "Stale text" })
    end.to raise_error(Concierge::RequestConflict)
    expect(Concierge::History.sources_current?(turn)).to be(true)
  end

  it "records quote amounts in integer cents, preserves versions and does not accept a foreign vendor" do
    vendor = create(:vendor, user:)
    result = execute("quotes.create", { event_plan_id: plan.id, vendor_id: vendor.id, amount_cents: 123456,
      currency: "CRC", scope_details: "Cena para seis", status: "received" })
    quote = user.vendor_quotes.sole
    expect(result.fetch("record")).to include("amount_cents" => 123456, "currency" => "CRC", "manual_record" => true)
    execute("quotes.update", { event_plan_id: plan.id, id: quote.id, lock_version: quote.lock_version, status: "under_review" })
    expect(quote.reload.status).to eq("under_review")
    expect do
      execute("quotes.create", { event_plan_id: plan.id, vendor_id: create(:vendor).id, amount_cents: 2000, currency: "USD", scope_details: "Foreign" })
    end.to raise_error(ActiveRecord::RecordNotFound)
    expect(user.vendor_quotes.count).to eq(1)
  end

  it "saves a manual booking, synchronizes its real task and timeline, and retires completed milestones" do
    create(:notification_preference, user:, time_zone: "America/Costa_Rica")
    result = execute("bookings.create", { event_plan_id: plan.id, title: "Birthday dinner", provider_name: "Casa Verde",
      starts_at: "2026-10-10T19:00:00-06:00", booking_kind: "reservation" })
    booking = user.bookings.sole
    expect(result.fetch("record")).to include("manual_record" => true, "starts_at" => "2026-10-10T19:00:00-06:00")
    expect(booking.plan_task).to be_present
    expect(booking.timeline_entry).to be_present
    reminder = create(:reminder, user:, relationship_profile: profile, event_plan: plan, booking:, booking_milestone: "confirmation")
    execute("bookings.update", { event_plan_id: plan.id, id: booking.id, lock_version: booking.lock_version,
      status: "confirmed", confirmation_details: "Confirmed manually by phone" })
    expect(booking.reload.plan_task).to be_completed
    expect(reminder.reload).to be_completed
    expect(Concierge::History.sources_current?(turn)).to be(true)
    expect(ExternalProviderAction.count).to eq(0)
  end

  it "requires confirmation before deleting a booking and its task, and rejects replay duplicates" do
    result = execute("bookings.create", { event_plan_id: plan.id, title: "Dinner", provider_name: "Casa Verde", starts_at: "2026-10-10T19:00:00-06:00" })
    booking = user.bookings.sole
    task_id = booking.plan_task_id
    execute("bookings.destroy", { event_plan_id: plan.id, id: booking.id })
    action = turn.actions.find_by!(name: "bookings.destroy")
    expect(booking.reload).to be_persisted
    2.times { Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint) }
    expect(Booking.exists?(result.fetch("record").fetch("id"))).to be(false)
    expect(PlanTask.exists?(task_id)).to be(false)
    expect(Concierge::History.sources_current?(turn)).to be(true)
  end

  it "rejects archived plans and foreign records before persisting manual work" do
    plan.archive!
    expect do
      execute("bookings.create", { event_plan_id: plan.id, title: "Dinner", provider_name: "Casa Verde", starts_at: "2026-10-10T19:00:00-06:00" })
    end.to raise_error(ActiveRecord::RecordNotFound)
    expect(user.bookings).to be_empty
    expect { execute("vendors.read", { id: create(:vendor).id }) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "manages selected work vendors, comparisons, quotes and booking records without exposing personal vendors" do
    personal = create(:vendor, user:, name: "Personal venue")
    profile.update!(relationship_mode: "professional", professional_context: { "event_plans" => [ plan.id ] })
    result = execute("vendors.create", { name: "Meeting venue", category: "restaurant" })
    vendor = user.vendors.find(result.fetch("record").fetch("id"))
    expect(profile.reload.work_context.selected("vendors").pluck(:id)).to eq([ vendor.id ])
    expect(execute("vendors.search").fetch("records").pluck("id")).to eq([ vendor.id ])
    expect { execute("vendors.read", { id: personal.id }) }.to raise_error(ActiveRecord::RecordNotFound)
    execute("vendors.attach", { id: vendor.id, event_plan_id: plan.id })
    comparison = execute("shortlists.create", { title: "Work venues", event_plan_id: plan.id, vendor_ids: [ vendor.id ] })
    shortlist = user.vendor_shortlists.find(comparison.fetch("record").fetch("id"))
    expect(profile.reload.work_context.selected("vendor_shortlists").pluck(:id)).to eq([ shortlist.id ])
    execute("vendor_options.select", { shortlist_id: shortlist.id, id: shortlist.vendor_options.sole.id })
    quote = execute("quotes.create", { event_plan_id: plan.id, vendor_id: vendor.id, amount_cents: 20000, currency: "USD", scope_details: "Meeting room" })
    expect(quote.fetch("record")).to include("manual_record" => true)
    booking = execute("bookings.create", { event_plan_id: plan.id, title: "Work meeting", provider_name: vendor.name, starts_at: "2026-10-10T19:00:00-06:00" })
    expect(booking.fetch("record")).to include("manual_record" => true)
    expect(user.bookings.sole.timeline_entry).to be_present
    expect(Concierge::History.sources_current?(turn)).to be(true)
    expect(ExternalProviderAction.count).to eq(0)
  end

  it "excludes unselected work vendors even inside a selected comparison or plan" do
    vendor = create(:vendor, user:, name: "Personal venue")
    shortlist = VendorShortlists::Create.call(user:, attributes: { title: "Old comparison", relationship_profile: profile, event_plan: plan }, vendors: [ vendor ])
    quote = create(:vendor_quote, user:, event_plan: plan, vendor:)
    profile.update!(relationship_mode: "professional", professional_context: { "event_plans" => [ plan.id ], "vendor_shortlists" => [ shortlist.id ] })
    expect(execute("shortlists.read", { id: shortlist.id }).fetch("records")).to be_empty
    expect(execute("quotes.search", { event_plan_id: plan.id }).fetch("records")).to be_empty
    expect { execute("quotes.read", { event_plan_id: plan.id, id: quote.id }) }.to raise_error(ActiveRecord::RecordNotFound)
    expect { execute("vendor_options.select", { shortlist_id: shortlist.id, id: shortlist.vendor_options.sole.id }) }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
