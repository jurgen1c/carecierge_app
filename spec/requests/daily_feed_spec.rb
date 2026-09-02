require "rails_helper"

RSpec.describe "Daily relationship feed", type: :request do
  it "links to the standalone vendor catalog in English and Spanish" do
    user = create(:user)
    sign_in user

    get dashboard_path
    expect(response.body).to include(vendors_path, ">Vendors<")

    I18n.with_locale(:es) { get dashboard_path }
    expect(response.body).to include(vendors_path, ">Proveedores<")
  end

  it "renders an owner-scoped concierge queue with source context and real navigation" do
    now = Time.zone.local(2026, 8, 14, 9)
    user = create(:user)
    profile = create(:relationship_profile, user:, preferred_name: "Taylor")
    create(:reminder, user:, relationship_profile: profile, title: "Follow up with Taylor", notes: "Share the introduction.", scheduled_at: now - 1.day)
    create(:reminder, title: "Another owner's private reminder", scheduled_at: now - 1.day)
    sign_in user

    Timecop.freeze(now) { get dashboard_path }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Concierge queue", "Needs attention", "Follow up with Taylor", "Share the introduction.")
    expect(response.body).to include(relationship_profiles_path, reminders_path, edit_notification_preference_path)
    expect(response.body).to include(data_control_path, audit_events_path, new_relationship_profile_path)
    expect(response.parsed_body.at_css("meta[name='turbo-cache-control']")&.[]("content")).to eq("no-cache")
    expect(response.parsed_body.css("form[data-action='submit->privacy-vault#lock']").size).to eq(2)
    expect(response.body).not_to include("Another owner's private reminder")
    expect(response.body).not_to match(/(?:emerald|amber)-/)
  end

  it "keeps admin activity discoverable for administrators" do
    user = create(:user, admin: true)
    sign_in user

    get dashboard_path

    expect(response.body).to include(admin_audit_events_path)
  end

  it "persists a feed-only dismissal without completing the source" do
    now = Time.zone.local(2026, 8, 14, 9)
    user = create(:user)
    reminder = create(:reminder, user:, relationship_profile: create(:relationship_profile, user:), scheduled_at: now)
    sign_in user

    Timecop.freeze(now) do
      patch dismiss_feed_item_path("reminder:#{reminder.id}")
    end

    expect(response).to redirect_to(dashboard_path)
    expect(user.feed_item_states.find_by!(item_key: "reminder:#{reminder.id}").dismissed_at).to eq(now)
    expect(reminder.reload).to be_active
  end

  it "snoozes a feed item until the next local morning and then returns it" do
    zone = ActiveSupport::TimeZone["America/Costa_Rica"]
    now = zone.local(2026, 8, 14, 15)
    user = create(:user)
    create(:notification_preference, user:, time_zone: zone.name, time_zone_configured: true)
    reminder = create(:reminder, user:, relationship_profile: create(:relationship_profile, user:), title: "Call Taylor", scheduled_at: now)
    sign_in user

    Timecop.freeze(now) { patch snooze_feed_item_path("reminder:#{reminder.id}") }

    state = user.feed_item_states.find_by!(item_key: "reminder:#{reminder.id}")
    expect(state.snoozed_until).to eq(zone.local(2026, 8, 15, 9))

    Timecop.freeze(now + 1.hour) { get dashboard_path }
    expect(response.body).not_to include("Call Taylor")

    Timecop.freeze(state.snoozed_until) { get dashboard_path }
    expect(response.body).to include("Call Taylor")
  end

  it "rejects feed actions for another owner's item" do
    user = create(:user)
    other_reminder = create(:reminder)
    sign_in user

    patch dismiss_feed_item_path("reminder:#{other_reminder.id}")

    expect(response).to have_http_status(:not_found)
    expect(user.feed_item_states).to be_empty
  end

  it "does not persist feed state when the source disappears before its lock is acquired" do
    user = create(:user)
    reminder = create(:reminder, user:)
    feed_item = DailyFeed::ForUser.find(user:, item_key: "reminder:#{reminder.id}")
    allow(DailyFeed::ForUser).to receive(:find).and_return(feed_item)
    allow(feed_item.source).to receive(:with_lock).and_raise(ActiveRecord::RecordNotFound)
    sign_in user

    patch dismiss_feed_item_path(feed_item.key)

    expect(response).to have_http_status(:not_found)
    expect(user.feed_item_states).to be_empty
  end

  it "locks the account before the feed source when persisting visibility state" do
    user = create(:user)
    reminder = create(:reminder, user:)
    sql = []
    subscriber = lambda do |_name, _started, _finished, _id, payload|
      sql << payload[:sql] unless payload[:name] == "SCHEMA" || payload[:cached]
    end
    sign_in user

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      patch dismiss_feed_item_path("reminder:#{reminder.id}")
    end

    account_lock = sql.index { |statement| statement.include?('FROM "users"') && statement.include?("FOR UPDATE") }
    source_lock = sql.index { |statement| statement.include?('FROM "reminders"') && statement.include?("FOR UPDATE") }
    expect(account_lock).to be_present
    expect(source_lock).to be_present
    expect(account_lock).to be < source_lock
  end

  it "allows actions on replacement items beyond the visible section limit" do
    now = Time.zone.local(2026, 8, 14, 9)
    user = create(:user)
    reminders = 9.times.map do |index|
      create(:reminder, user:, title: "Reminder #{index}", scheduled_at: now + index.minutes)
    end
    reminders.first(8).each do |reminder|
      create(:feed_item_state, user:, item_key: "reminder:#{reminder.id}", dismissed_at: now)
    end
    sign_in user

    Timecop.freeze(now) { patch dismiss_feed_item_path("reminder:#{reminders.last.id}") }

    expect(response).to redirect_to(dashboard_path)
    expect(user.feed_item_states.find_by!(item_key: "reminder:#{reminders.last.id}")).to be_present
  end

  it "keeps a bounded feed suggestion actionable through canonical suggestion resolution" do
    now = Time.zone.local(2026, 8, 14, 9)
    user = create(:user)
    profile = create(:relationship_profile, user:, type: "RelationshipProfiles::Colleague")
    canonical = create(:commitment, relationship_profile: profile, due_on: now.to_date - 2.days, title: "Canonical follow-up")
    create(:commitment, relationship_profile: profile, due_on: now.to_date - 1.day, title: "Fallback follow-up")
    create(:relationship_preference, relationship_profile: profile, confidence: "confirmed")
    create(:reminder, user:, relationship_profile: profile, commitment: canonical, scheduled_at: now)
    feed_item = DailyFeed::ForUser.call(user:, as_of: now).items.find { |item| item.kind == "suggestion" }
    expect(feed_item.suggestion.suggestion_type).to eq("message")
    sign_in user

    Timecop.freeze(now) do
      post act_relationship_profile_suggestion_path(profile, feed_item.suggestion.fingerprint)
    end

    expect(response).to redirect_to(
      new_reminder_path(relationship_profile_id: profile.id, suggestion: feed_item.suggestion.fingerprint)
    )
  end

  it "renders the queue and actions in Spanish" do
    now = Time.zone.local(2026, 8, 14, 9)
    user = create(:user)
    create(:reminder, user:, relationship_profile: create(:relationship_profile, user:), title: "Llamar a Taylor", scheduled_at: now)
    sign_in user

    Timecop.freeze(now) { I18n.with_locale(:es) { get dashboard_path } }

    expect(response.body).to include("Cola de concierge", "Necesita atención", "Posponer", "Descartar")
    expect(response.body).not_to include("Translation missing")
  end
end
