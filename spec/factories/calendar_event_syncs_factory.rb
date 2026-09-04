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
FactoryBot.define do
  factory :calendar_event_sync do
    calendar_connection
    source { association :reminder, user: calendar_connection.user, relationship_profile: association(:relationship_profile, user: calendar_connection.user) }
    external_event_id { "google-event-1" }
    source_fingerprint { "a" * 64 }
    synced_at { Time.current }
  end
end
