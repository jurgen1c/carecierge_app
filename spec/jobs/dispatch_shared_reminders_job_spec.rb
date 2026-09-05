require "rails_helper"

RSpec.describe DispatchSharedRemindersJob, type: :job do
  it "delivers only explicit in-app subscriptions once per scheduled occurrence" do
    Timecop.freeze(Time.utc(2026, 9, 5, 15)) do
      item = create(:shared_item, kind: "reminder", due_at: 1.minute.ago)
      space = item.shared_relationship_space
      subscription = item.shared_reminder_subscriptions.create!(user: space.owner)
      expect { described_class.perform_now }.to change(space.owner.notifications, :count).by(1)
      expect(space.partner.notifications.count).to eq(0)
      expect { described_class.perform_now }.not_to change(Noticed::Notification, :count)
      expect(subscription.reload.delivered_for).to eq(item.due_at)
      notification = space.owner.notifications.last
      expect(notification.message).to eq("A reminder in your shared space is due.")
      expect(notification.url).to include(space.id)
      expect(notification.message).not_to include(item.title)
    end
  end

  it "honors in-app preferences, quiet hours, completion and subscription withdrawal" do
    Timecop.freeze(Time.utc(2026, 9, 5, 15)) do
      item = create(:shared_item, kind: "reminder", due_at: 1.minute.ago)
      owner = item.creator
      subscription = item.shared_reminder_subscriptions.create!(user: owner)
      preference = create(:notification_preference, user: owner, in_app_enabled: false)
      expect { described_class.perform_now }.not_to change(Noticed::Notification, :count)
      preference.update!(in_app_enabled: true, quiet_hours_enabled: true, quiet_hours_start: "14:00", quiet_hours_end: "16:00", time_zone: "UTC")
      expect { described_class.perform_now }.not_to change(Noticed::Notification, :count)
      preference.update!(quiet_hours_enabled: false)
      item.update!(completed_at: Time.current)
      expect { described_class.perform_now }.not_to change(Noticed::Notification, :count)
      item.update!(completed_at: nil)
      subscription.destroy!
      expect { described_class.perform_now }.not_to change(Noticed::Notification, :count)
    end
  end

  it "enqueues through Active Job and removes notification history when sharing ends" do
    item = create(:shared_item, kind: "reminder", due_at: 1.minute.ago)
    item.shared_reminder_subscriptions.create!(user: item.creator)
    expect { described_class.perform_later }.to have_enqueued_job(described_class)
    described_class.perform_now
    expect { item.shared_relationship_space.end_sharing!(item.creator) }.to change(Noticed::Notification, :count).by(-1)
  end
  it "skips an item removed between subscription discovery and association loading" do
    item = create(:shared_item, kind: "reminder", due_at: 1.minute.ago)
    item.shared_reminder_subscriptions.create!(user: item.creator)
    allow_any_instance_of(SharedReminderSubscription).to receive(:shared_item).and_return(nil)
    expect { described_class.perform_now }.not_to raise_error
  end

  it "skips a space removed between subscription discovery and association loading" do
    item = create(:shared_item, kind: "reminder", due_at: 1.minute.ago)
    item.shared_reminder_subscriptions.create!(user: item.creator)
    allow_any_instance_of(SharedItem).to receive(:shared_relationship_space).and_return(nil)
    expect { described_class.perform_now }.not_to raise_error
  end

  it "discovers pending occurrences without revisiting delivered history and recognizes reschedules" do
    item = create(:shared_item, kind: "reminder", due_at: 1.minute.ago)
    subscription = item.shared_reminder_subscriptions.create!(user: item.creator)
    expect(SharedReminderSubscription.pending_delivery).to include(subscription)
    described_class.perform_now
    expect(SharedReminderSubscription.pending_delivery).not_to include(subscription)
    item.update!(due_at: 2.minutes.ago)
    expect(SharedReminderSubscription.pending_delivery).to include(subscription)
  end
  it "batches association discovery while retaining each locked delivery recheck" do
    3.times do
      item = create(:shared_item, kind: "reminder", due_at: 1.minute.ago)
      item.shared_reminder_subscriptions.create!(user: item.creator)
      create(:notification_preference, user: item.creator, in_app_enabled: false)
    end
    queries = []
    subscriber = lambda do |*, payload|
      queries << payload[:sql] unless payload[:cached] || payload[:name] == "SCHEMA"
    end
    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { described_class.perform_now }
    reads = queries.grep(/SELECT .* FROM "shared_relationship_spaces"/)
    expect(reads.grep(/FOR UPDATE/).size).to eq(3)
    expect(reads.reject { |sql| sql.include?("FOR UPDATE") }.size).to be <= 4
    expect(Noticed::Notification.count).to eq(0)
  end
  it "does not replay an occurrence after reminders are turned off and on again" do
    item = create(:shared_item, kind: "reminder", due_at: 1.minute.ago)
    space, actor = item.shared_relationship_space, item.creator
    SharedSpaces::ChangeItem.call(space:, actor:, item:, action: :subscribe)
    described_class.perform_now
    expect(actor.notifications.count).to eq(1)
    SharedSpaces::ChangeItem.call(space:, actor:, item:, action: :unsubscribe)
    expect(SharedReminderSubscription.pending_delivery).to be_empty
    SharedSpaces::ChangeItem.call(space:, actor:, item:, action: :subscribe)
    expect { described_class.perform_now }.not_to change(Noticed::Notification, :count)
    item.update!(due_at: 2.minutes.ago)
    expect { described_class.perform_now }.to change(Noticed::Notification, :count).by(1)
  end
end
