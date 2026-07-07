# == Schema Information
#
# Table name: desire_fulfillments
# Database name: primary
#
#  id           :uuid             not null, primary key
#  fulfilled_on :date             not null
#  notes        :text
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  desire_id    :uuid             not null
#
# Indexes
#
#  index_desire_fulfillments_on_desire_id                   (desire_id)
#  index_desire_fulfillments_on_desire_id_and_fulfilled_on  (desire_id,fulfilled_on)
#
# Foreign Keys
#
#  fk_rails_...  (desire_id => desires.id)
#
FactoryBot.define do
  factory :desire_fulfillment do
    desire
    fulfilled_on { Date.new(2026, 7, 7) }
    notes { nil }
  end
end
