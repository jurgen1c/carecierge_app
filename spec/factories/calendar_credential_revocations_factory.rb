# == Schema Information
#
# Table name: calendar_credential_revocations
# Database name: primary
#
#  id              :uuid             not null, primary key
#  access_token    :text
#  attempts        :integer          default(0), not null
#  last_error_code :string
#  lock_version    :integer          default(0), not null
#  refresh_token   :text
#  retry_at        :datetime         not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  user_id         :uuid             not null
#
# Indexes
#
#  index_calendar_credential_revocations_on_retry_at  (retry_at)
#  index_calendar_credential_revocations_on_user_id   (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :calendar_credential_revocation do
    user
    access_token { "uncommitted-access-token" }
    refresh_token { "uncommitted-refresh-token" }
    retry_at { Time.current }
  end
end
