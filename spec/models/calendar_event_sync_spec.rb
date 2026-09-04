require "rails_helper"

# == Schema Information
#
# Table name: calendar_event_syncs
# Database name: primary
#
#  id                     :uuid             not null, primary key
#  source_fingerprint     :string           not null
#  source_type            :string           not null
#  synced_at              :datetime
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  calendar_connection_id :uuid             not null
#  external_event_id      :text             not null
#  source_id              :uuid             not null
#
# Indexes
#
#  index_calendar_event_syncs_on_calendar_connection_id  (calendar_connection_id)
#  index_calendar_event_syncs_on_connection_and_source   (calendar_connection_id,source_type,source_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (calendar_connection_id => calendar_connections.id) ON DELETE => cascade
#
RSpec.describe CalendarEventSync do
  it "requires the source to belong to the connection owner" do
    connection = create(:calendar_connection)
    foreign_reminder = create(:reminder)

    sync = build(:calendar_event_sync, calendar_connection: connection, source: foreign_reminder)

    expect(sync).not_to be_valid
    expect(sync.errors[:source]).to be_present
  end

  it "stores an encrypted provider event identifier" do
    expect(described_class.encrypted_attributes).to include(:external_event_id)
  end

  it "allows a pending provider insert without a synced timestamp" do
    expect(create(:calendar_event_sync, synced_at: nil)).to be_valid
  end
end
