require "rails_helper"

RSpec.describe ReminderMailer, type: :mailer do
  it "renders a localized reminder email without exposing private notes in the subject" do
    reminder = create(:reminder, title: "Call Elena", notes: "Sensitive context")

    mail = described_class.with(record: reminder, recipient: reminder.user).due

    expect(mail.to).to eq([ reminder.user.email ])
    expect(mail.subject).to eq("Reminder: Call Elena")
    expect(mail.body.encoded).to include("Call Elena")
    expect(mail.body.encoded).to include("Open reminders")
  end

  it "renders the scheduled time in Spanish without falling back to English" do
    reminder = create(:reminder, title: "Llamar a Elena", scheduled_at: Time.zone.local(2026, 7, 14, 17, 30))

    mail = I18n.with_locale(:es) do
      described_class.with(record: reminder, recipient: reminder.user).due.message
    end

    expect(mail.subject).to eq("Recordatorio: Llamar a Elena")
    expect(mail.body.encoded).to include("14/7/2026 17:30")
  end

  it "reports the effective snoozed delivery time" do
    reminder = create(
      :reminder,
      scheduled_at: Time.zone.local(2026, 7, 14, 9, 0),
      snoozed_until: Time.zone.local(2026, 7, 15, 14, 30)
    )

    mail = described_class.with(record: reminder, recipient: reminder.user).due

    expect(mail.body.encoded).to include("July 15, 2026 14:30")
    expect(mail.body.encoded).not_to include("July 14, 2026 09:00")
  end

  it "links archived relationship reminders to the unfiltered inbox" do
    reminder = create(:reminder)
    reminder.relationship_profile.discard!

    mail = described_class.with(record: reminder, recipient: reminder.user).due

    expect(mail.body.encoded).to include(reminders_url)
    expect(mail.body.encoded).not_to include("relationship_profile_id=#{reminder.relationship_profile_id}")
  end
end
