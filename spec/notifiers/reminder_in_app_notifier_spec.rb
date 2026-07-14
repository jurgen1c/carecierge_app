require "rails_helper"

RSpec.describe ReminderInAppNotifier do
  it "creates a renderable private notification for the reminder owner" do
    reminder = create(:reminder, title: "Call Elena")

    expect do
      described_class.with(record: reminder).deliver(reminder.user)
    end.to change(reminder.user.notifications, :count).by(1)

    notification = reminder.user.notifications.last
    expect(notification.message).to eq("Call Elena is due.")
    expect(notification.url).to eq(Rails.application.routes.url_helpers.reminders_path(relationship_profile_id: reminder.relationship_profile_id))
  end

  it "links archived relationship reminders to the unfiltered inbox" do
    reminder = create(:reminder)
    reminder.relationship_profile.discard!

    described_class.with(record: reminder).deliver(reminder.user)

    expect(reminder.user.notifications.last.url).to eq(Rails.application.routes.url_helpers.reminders_path)
  end
end
