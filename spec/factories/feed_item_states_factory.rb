# == Schema Information
#
# Table name: feed_item_states
# Database name: primary
#
#  id            :uuid             not null, primary key
#  dismissed_at  :datetime
#  item_key      :string           not null
#  snoozed_until :datetime
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_id       :uuid             not null
#
# Indexes
#
#  index_feed_item_states_on_user_id                    (user_id)
#  index_feed_item_states_on_user_id_and_item_key       (user_id,item_key) UNIQUE
#  index_feed_item_states_on_user_id_and_snoozed_until  (user_id,snoozed_until) WHERE (snoozed_until IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :feed_item_state do
    user
    sequence(:item_key) { |number| "reminder:#{number}" }
    dismissed_at { Time.current }
    snoozed_until { nil }
  end
end
