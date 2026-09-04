require "rails_helper"

RSpec.describe DispatchCalendarCredentialRevocationsJob, type: :job do
  it "queues due retained credentials and leaves later retries alone" do
    due = create(:calendar_credential_revocation, retry_at: 1.minute.ago)
    create(:calendar_credential_revocation, retry_at: 1.minute.from_now)

    expect { described_class.perform_now }
      .to have_enqueued_job(CalendarCredentialRevocationJob).with(due).once
  end
end
