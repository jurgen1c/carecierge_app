require "rails_helper"

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
RSpec.describe CalendarCredentialRevocation do
  it "retains either token while rejecting an empty credential set" do
    access_only = build(:calendar_credential_revocation, access_token: "access-only", refresh_token: nil)
    refresh_only = build(:calendar_credential_revocation, access_token: nil, refresh_token: "refresh-only")
    empty = build(:calendar_credential_revocation, access_token: nil, refresh_token: nil)

    expect(access_only).to be_valid
    expect(refresh_only).to be_valid
    expect(empty).not_to be_valid
  end
end
