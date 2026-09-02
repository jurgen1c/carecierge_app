# == Schema Information
#
# Table name: event_plan_vendors
# Database name: primary
#
#  id            :uuid             not null, primary key
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  event_plan_id :uuid             not null
#  vendor_id     :uuid             not null
#
# Indexes
#
#  index_event_plan_vendors_on_event_plan_id                (event_plan_id)
#  index_event_plan_vendors_on_event_plan_id_and_vendor_id  (event_plan_id,vendor_id) UNIQUE
#  index_event_plan_vendors_on_vendor_id                    (vendor_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_plan_id => event_plans.id) ON DELETE => cascade
#  fk_rails_...  (vendor_id => vendors.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :event_plan_vendor do
    association :event_plan
    vendor { association(:vendor, user: event_plan.user) }
  end
end
