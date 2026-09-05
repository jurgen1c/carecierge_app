require "rails_helper"

RSpec.describe CalendarSyncJob, type: :job do
  it "executes the connection reconciliation" do
    connection = create(:calendar_connection)
    allow(CalendarSyncs::Run).to receive(:call)

    described_class.perform_now(connection)

    expect(CalendarSyncs::Run).to have_received(:call).with(connection:, owner_requested: false)
  end

  it "preserves an explicit owner recovery request" do
    connection = create(:calendar_connection, sync_status: "failed", last_error_code: "provider_rejected")
    allow(CalendarSyncs::Run).to receive(:call)

    described_class.perform_now(connection, owner_requested: true)

    expect(CalendarSyncs::Run).to have_received(:call).with(connection:, owner_requested: true)
  end
end
