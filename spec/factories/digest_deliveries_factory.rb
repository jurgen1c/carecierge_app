# == Schema Information
#
# Table name: digest_deliveries
# Database name: primary
#
#  id                 :uuid             not null, primary key
#  channel            :string           not null
#  dispatched_at      :datetime
#  email_delivered_at :datetime
#  enqueued_at        :datetime
#  error_message      :text
#  handed_off_at      :datetime
#  mode               :string           not null
#  scheduled_for      :datetime         not null
#  status             :string           default("pending"), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  user_id            :uuid             not null
#
# Indexes
#
#  index_digest_deliveries_on_recoverable_lease    (enqueued_at) WHERE ((status)::text = ANY ((ARRAY['pending'::character varying, 'dispatching'::character varying])::text[]))
#  index_digest_deliveries_on_user_and_occurrence  (user_id,scheduled_for) UNIQUE
#  index_digest_deliveries_on_user_id              (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :digest_delivery do
    user
    channel { "email" }
    mode { "daily" }
    scheduled_for { Time.current }
    status { "pending" }
    enqueued_at { nil }
    dispatched_at { nil }
    error_message { nil }
  end
end
