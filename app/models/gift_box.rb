# == Schema Information
#
# Table name: gift_boxes
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  budget                  :decimal(12, 2)
#  constraints             :text
#  currency                :string           default("USD"), not null
#  delivery_on             :date
#  lock_version            :integer          default(0), not null
#  name                    :text             not null
#  notes                   :text
#  occasion                :text             not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  index_gift_boxes_on_relationship_profile_id  (relationship_profile_id)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#
class GiftBox < ApplicationRecord
  belongs_to :relationship_profile
  has_many :items, class_name: "GiftBoxItem", dependent: :destroy, inverse_of: :gift_box
  accepts_nested_attributes_for :items, allow_destroy: true, limit: 30, reject_if: :blank_item?
  encrypts :name, :occasion, :notes, :constraints

  normalizes :currency, with: ->(value) { value.to_s.strip.upcase }
  validates :name, :occasion, presence: true, length: { maximum: 200 }
  validates :notes, :constraints, length: { maximum: 2_000 }
  validates :currency, format: { with: /\A[A-Z]{3}\z/ }
  validates :delivery_on, comparison: { less_than_or_equal_to: Date.new(9999, 12, 31) }, allow_nil: true
  validate :valid_budget
  validate :bounded_items

  def known_total
    items.reject(&:marked_for_destruction?).sum { |item| item.cost || 0 }
  end

  def remaining_budget
    budget && budget - known_total
  end

  private

  def blank_item?(attributes)
    attributes.except("purchased", "completed", "_destroy").values.all?(&:blank?)
  end

  def valid_budget
    raw = budget_before_type_cast
    raw = raw.to_s("F") if raw.is_a?(BigDecimal)
    errors.add(:budget, :invalid) if raw.present? && !raw.to_s.match?(GiftPurchasePlan::MONEY_PATTERN)
  end

  def bounded_items
    errors.add(:items, :too_long, count: 30) if items.reject(&:marked_for_destruction?).size > 30
  end
end
