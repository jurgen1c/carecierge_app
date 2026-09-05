require "rails_helper"

# == Schema Information
#
# Table name: calendar_connections
# Database name: primary
#
#  id                    :uuid             not null, primary key
#  access_token          :text             not null
#  granted_scopes        :string           default([]), not null, is an Array
#  last_error_at         :datetime
#  last_error_code       :string
#  last_sync_started_at  :datetime
#  last_synced_at        :datetime
#  locale                :string           default("en"), not null
#  lock_version          :integer          default(0), not null
#  pending_audit_count   :integer          default(0), not null
#  provider              :string           default("google_calendar"), not null
#  refresh_token         :text             not null
#  resync_requested      :boolean          default(FALSE), not null
#  sync_lease_expires_at :datetime
#  sync_lease_token      :uuid
#  sync_status           :string           default("connected"), not null
#  sync_types            :string           default([]), not null, is an Array
#  token_expires_at      :datetime         not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  user_id               :uuid             not null
#
# Indexes
#
#  index_calendar_connections_on_sync_lease  (sync_status,sync_lease_expires_at)
#  index_calendar_connections_on_user_id     (user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
RSpec.describe CalendarConnection do
  it "stores one encrypted Google connection per owner" do
    connection = create(:calendar_connection)

    expect(connection).to be_valid
    expect(described_class.encrypted_attributes).to include(:access_token, :refresh_token)
    expect { create(:calendar_connection, user: connection.user) }
      .to raise_error(ActiveRecord::RecordInvalid)
  end

  it "accepts only unique supported sync types and the required narrow scope" do
    connection = build(:calendar_connection, sync_types: [ "reminders", "unknown" ])
    expect(connection).not_to be_valid

    connection.sync_types = [ "reminders", "reminders" ]
    expect(connection).not_to be_valid

    connection.sync_types = [ "reminders" ]
    connection.granted_scopes = []
    expect(connection).not_to be_valid
  end

  it "accepts only configured interface locales" do
    connection = build(:calendar_connection, locale: "fr")

    expect(connection).not_to be_valid
    expect(connection.errors[:locale]).to be_present
  end

  it "rejects error details outside the safe public code list" do
    connection = build(:calendar_connection, last_error_code: "private provider response")

    expect(connection).not_to be_valid
    expect(connection.errors[:last_error_code]).to be_present
  end

  it "never includes credentials in inspect output" do
    connection = build(:calendar_connection, access_token: "private-access", refresh_token: "private-refresh")

    expect(connection.inspect).not_to include("private-access", "private-refresh")
  end

  it "requires a complete lease only while syncing" do
    connection = build(:calendar_connection, sync_status: "syncing")
    expect(connection).not_to be_valid

    connection.sync_lease_token = SecureRandom.uuid
    connection.sync_lease_expires_at = 1.minute.from_now
    expect(connection).to be_valid

    connection.sync_status = "connected"
    expect(connection).not_to be_valid
  end

  it "rejects a negative pending audit count" do
    connection = build(:calendar_connection, pending_audit_count: -1)

    expect(connection).not_to be_valid
    expect(connection.errors[:pending_audit_count]).to be_present
  end


  it "separates automatic retry eligibility from owner-requested recovery" do
    connection = build(:calendar_connection, sync_status: "failed", last_error_code: "provider_rejected")

    expect(connection).not_to be_syncable
    expect(connection.syncable?(owner_requested: true)).to be(true)

    connection.last_error_code = "revocation_failed"
    expect(connection.syncable?(owner_requested: true)).to be(false)
  end
end
