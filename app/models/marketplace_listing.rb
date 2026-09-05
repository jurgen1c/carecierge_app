# == Schema Information
#
# Table name: marketplace_listings
# Database name: primary
#
#  id                     :uuid             not null, primary key
#  category               :string           not null
#  curated_summary        :text             not null
#  name                   :string           not null
#  occasion_types         :string           default([]), not null, is an Array
#  provider_details       :text             not null
#  provider_name          :string           not null
#  published              :boolean          default(FALSE), not null
#  relationship_use_cases :text             not null
#  reviewed_on            :date             not null
#  service_area           :string           not null
#  source_url             :string           not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_marketplace_listings_on_published_and_category  (published,category)
#
class MarketplaceListing < ApplicationRecord
  MAX_COMPARISON = 5

  has_many :vendors, dependent: :nullify

  validates :name, :service_area, :provider_name, presence: true, length: { maximum: 200 }
  validates :curated_summary, :provider_details, :relationship_use_cases, presence: true, length: { maximum: 2_000 }
  validates :category, inclusion: { in: Vendor::CATEGORIES }
  validates :reviewed_on, presence: true
  validates :source_url, presence: true, length: { maximum: 2_000 }
  validate :safe_source_url
  validate :valid_occasions

  scope :published, -> { where(published: true) }
  scope :ordered, -> { order(:name, :id) }
  scope :for_occasion, ->(occasion) { where("? = ANY(occasion_types)", occasion) }

  def self.ransackable_attributes(_auth_object = nil)
    %w[name curated_summary service_area category relationship_use_cases]
  end

  def self.ransackable_associations(_auth_object = nil) = []

  def vendor_attributes
    {
      name:, category:, location: service_area, occasion_types:,
      source_kind: "external", source_name: provider_name, source_url:,
      marketplace_listing: self
    }
  end

  private

  def safe_source_url
    uri = URI.parse(source_url.to_s)
    return if uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil?

    errors.add(:source_url, :invalid)
  rescue URI::InvalidURIError
    errors.add(:source_url, :invalid)
  end

  def valid_occasions
    return if occasion_types.is_a?(Array) && occasion_types.length <= Vendor::MAX_TAGS &&
      (occasion_types - EventPlan::OCCASION_TYPES).empty?

    errors.add(:occasion_types, :invalid)
  end
end
