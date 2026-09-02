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
class EventPlanVendor < ApplicationRecord
  belongs_to :event_plan
  belongs_to :vendor

  validates :vendor_id, uniqueness: { scope: :event_plan_id }
  validate :owners_match
  validate :event_plan_is_active, on: :create

  private

  def owners_match
    return if event_plan.blank? || vendor.blank? || event_plan.user_id == vendor.user_id

    errors.add(:vendor, :different_owner)
  end

  def event_plan_is_active
    return if event_plan.blank? || event_plan.active?

    errors.add(:event_plan, :inactive)
  end
end
