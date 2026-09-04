require "rails_helper"

RSpec.describe CalendarCredentialRevocationJob, type: :job do
  it "deletes credentials only after Google confirms revocation" do
    revocation = create(:calendar_credential_revocation)
    credentials = revocation.credentials
    allow(CalendarConnections::GoogleOauth).to receive(:revoke).with(credentials:).and_return(true)

    expect { described_class.perform_now(revocation) }
      .to change(CalendarCredentialRevocation, :count).by(-1)
  end

  it "keeps failed credentials eligible for a later retry" do
    revocation = create(:calendar_credential_revocation)
    allow(CalendarConnections::GoogleOauth).to receive(:revoke)
      .and_raise(CalendarConnections::ConnectionError.new(code: "provider_unavailable"))

    expect { described_class.perform_now(revocation) }.not_to change(CalendarCredentialRevocation, :count)

    expect(revocation.reload).to have_attributes(attempts: 1, last_error_code: "provider_unavailable")
    expect(revocation.retry_at).to be_future
  end

  it "does not bypass a later retry time when duplicate jobs are queued" do
    revocation = create(:calendar_credential_revocation, retry_at: 5.minutes.from_now)
    allow(CalendarConnections::GoogleOauth).to receive(:revoke)

    described_class.perform_now(revocation)

    expect(CalendarConnections::GoogleOauth).not_to have_received(:revoke)
    expect(revocation.reload.attempts).to eq(0)
  end

  it "treats credentials removed by a concurrent revocation job as already complete" do
    revocation = create(:calendar_credential_revocation)
    allow(revocation).to receive(:with_lock).and_raise(ActiveRecord::RecordNotFound)

    expect { described_class.perform_now(revocation) }.not_to raise_error
  end
end
