# == Schema Information
#
# Table name: vendor_quotes
# Database name: primary
#
#  id              :uuid             not null, primary key
#  amount_cents    :integer          not null
#  currency        :string           default("USD"), not null
#  decision_due_on :date
#  expires_on      :date
#  lock_version    :integer          default(0), not null
#  next_action     :text
#  notes           :text
#  scope_details   :text             not null
#  status          :string           default("draft"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  event_plan_id   :uuid             not null
#  user_id         :uuid             not null
#  vendor_id       :uuid             not null
#
# Indexes
#
#  index_vendor_quotes_on_event_plan_id               (event_plan_id)
#  index_vendor_quotes_on_plan_status_and_expiration  (event_plan_id,status,expires_on)
#  index_vendor_quotes_on_user_id                     (user_id)
#  index_vendor_quotes_on_user_id_and_created_at      (user_id,created_at)
#  index_vendor_quotes_on_vendor_id                   (vendor_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_plan_id => event_plans.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#  fk_rails_...  (vendor_id => vendors.id)
#
FactoryBot.define do
  factory :vendor_quote do
    association :user
    event_plan { association(:event_plan, user:) }
    vendor { association(:vendor, user:) }
    amount { "1250.00" }
    currency { "USD" }
    scope_details { "Full-service catering for twelve guests" }
    expires_on { Date.new(2026, 9, 18) }
    decision_due_on { Date.new(2026, 9, 16) }
    status { "received" }
    next_action { "Confirm the catering minimum" }
    notes { "Includes staffing and basic decor." }
  end
end
