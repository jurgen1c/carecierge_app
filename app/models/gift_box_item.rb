# == Schema Information
#
# Table name: gift_box_items
# Database name: primary
#
#  id           :uuid             not null, primary key
#  completed    :boolean          default(FALSE), not null
#  cost         :decimal(12, 2)
#  name         :text             not null
#  notes        :text
#  purchase_url :text
#  purchased    :boolean          default(FALSE), not null
#  vendor       :text
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  gift_box_id  :uuid             not null
#
# Indexes
#
#  index_gift_box_items_on_gift_box_id  (gift_box_id)
#
# Foreign Keys
#
#  fk_rails_...  (gift_box_id => gift_boxes.id) ON DELETE => cascade
#
class GiftBoxItem < ApplicationRecord
  belongs_to :gift_box, inverse_of: :items
  encrypts :name, :notes, :vendor, :purchase_url
  validates :name, presence: true, length: { maximum: 200 }
  validates :vendor, length: { maximum: 200 }
  validates :notes, :purchase_url, length: { maximum: 2_000 }
  validate :valid_cost
  validate :safe_purchase_url

  private

  def valid_cost
    raw = cost_before_type_cast
    raw = raw.to_s("F") if raw.is_a?(BigDecimal)
    errors.add(:cost, :invalid) if raw.present? && !raw.to_s.match?(GiftPurchasePlan::MONEY_PATTERN)
  end

  def safe_purchase_url
    return if purchase_url.blank?

    uri = URI.parse(purchase_url)
    errors.add(:purchase_url, :invalid) unless uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil?
  rescue URI::InvalidURIError
    errors.add(:purchase_url, :invalid)
  end
end
