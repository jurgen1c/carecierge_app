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
FactoryBot.define do
  factory :calendar_connection do
    user
    provider { "google_calendar" }
    locale { "en" }
    access_token { "access-token" }
    refresh_token { "refresh-token" }
    token_expires_at { 1.hour.from_now }
    granted_scopes { [ CalendarConnection::GOOGLE_SCOPE ] }
    sync_types { CalendarConnection::SYNC_TYPES }
    sync_status { "connected" }
  end
end
