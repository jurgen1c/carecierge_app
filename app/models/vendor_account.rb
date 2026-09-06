# == Schema Information
#
# Table name: vendor_accounts
# Database name: primary
#
#  id               :uuid             not null, primary key
#  business_name    :string           default(""), not null
#  categories       :string           default([]), not null, is an Array
#  contact_channels :text             default(""), not null
#  lock_version     :integer          default(0), not null
#  offerings        :text             default(""), not null
#  provenance       :text             default(""), not null
#  service_area     :string           default(""), not null
#  source_url       :text             default(""), not null
#  status           :string           default("draft"), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  user_id          :uuid             not null
#
# Indexes
#
#  index_vendor_accounts_on_status_and_updated_at  (status,updated_at)
#  index_vendor_accounts_on_user_id                (user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class VendorAccount < ApplicationRecord
  STATUSES = %w[draft submitted approved rejected suspended].freeze
  PROFILE_FIELDS = %w[business_name categories service_area offerings contact_channels source_url provenance].freeze

  belongs_to :user
  has_one :marketplace_listing, dependent: :destroy
  has_many :reviews, class_name: "VendorAccountReview", dependent: :delete_all, inverse_of: :vendor_account

  validates :user_id, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :business_name, :service_area, length: { maximum: 200 }
  validates :offerings, :source_url, length: { maximum: 2_000 }
  validates :contact_channels, :provenance, length: { maximum: 950 }
  validates(*PROFILE_FIELDS, presence: true, if: -> { status.in?(%w[submitted approved]) })
  validate :bounded_categories
  validate :safe_source

  def profile_snapshot = attributes.slice(*PROFILE_FIELDS)

  def verify_version!(version)
    unless version.is_a?(String) && version.match?(/\A\d+\z/) && version.to_i == lock_version
      raise ActiveRecord::StaleObjectError.new(self, "update")
    end
  end

  def record_transition!(from:, actor:, reason: nil)
    reviews.create!(from_status: from, to_status: status, actor:, reason:,
      profile_version: lock_version, profile_snapshot:)
  end

  private

  def bounded_categories
    return if categories.is_a?(Array) && categories.length <= 5 && categories.uniq == categories &&
      (categories - Vendor::CATEGORIES).empty?

    errors.add(:categories, :invalid)
  end

  def safe_source
    return if source_url.blank?
    uri = URI.parse(source_url)
    return if uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil?
    errors.add(:source_url, :invalid)
  rescue URI::InvalidURIError
    errors.add(:source_url, :invalid)
  end
end
