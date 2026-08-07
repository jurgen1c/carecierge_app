require "rails_helper"

RSpec.describe AuditEvents::Query do
  it "filters the provided scope by account, action, source, and inclusive local dates" do
    user = create(:user)
    other_user = create(:user)
    matching = create(
      :audit_event,
      user:,
      actor: user,
      action: "reminder.created",
      source: "web_app",
      occurred_at: Time.zone.local(2026, 8, 5, 14)
    )
    create(:audit_event, user:, actor: user, action: "reminder.completed", occurred_at: Time.zone.local(2026, 8, 5, 15))
    create(:audit_event, user: other_user, actor: other_user, action: "reminder.created", occurred_at: Time.zone.local(2026, 8, 5, 16))

    query = described_class.new(
      AuditEvent.all,
      filters: {
        user_id: user.id.upcase,
        event_action: "reminder.created",
        source: "web_app",
        occurred_from: "2026-08-05",
        occurred_to: "2026-08-05"
      }
    )

    expect(query.resolve).to contain_exactly(matching)
    expect(query.user_id).to eq(user.id)
  end

  it "fails closed for malformed or unsupported filters" do
    event = create(:audit_event)

    expect(described_class.new(AuditEvent.all, filters: { user_id: "not-a-uuid" }).resolve).to be_empty
    expect(described_class.new(AuditEvent.all, filters: { event_action: "private.payload.viewed" }).resolve).to be_empty
    expect(described_class.new(AuditEvent.all, filters: { source: "browser-extension" }).resolve).to be_empty
    expect(described_class.new(AuditEvent.all, filters: { occurred_from: "not-a-date" }).resolve).to be_empty
    expect(described_class.new(AuditEvent.all, filters: { occurred_from: "9999999999-01-01" }).resolve).to be_empty
    expect(AuditEvent.where(id: event.id)).to exist
  end

  it "fails closed for non-scalar filter shapes, including empty collections" do
    create(:audit_event)

    expect(described_class.new(AuditEvent.all, filters: { event_action: [ "reminder.created" ] }).resolve).to be_empty
    expect(described_class.new(AuditEvent.all, filters: { source: { value: "web_app" } }).resolve).to be_empty
    expect(described_class.new(AuditEvent.all, filters: { occurred_from: [] }).resolve).to be_empty
    expect(described_class.new(AuditEvent.all, filters: { user_id: {} }).resolve).to be_empty
  end

  it "applies date filters in the supplied account time zone" do
    user = create(:user)
    local_evening = create(:audit_event, user:, actor: user, occurred_at: Time.utc(2026, 8, 6, 5, 30))
    create(:audit_event, user:, actor: user, occurred_at: Time.utc(2026, 8, 6, 6, 30))

    query = described_class.new(
      user.audit_events,
      filters: { occurred_from: "2026-08-05", occurred_to: "2026-08-05" },
      time_zone: "America/Costa_Rica"
    )

    expect(query.resolve).to contain_exactly(local_evening)
  end
end
