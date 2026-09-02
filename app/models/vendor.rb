# == Schema Information
#
# Table name: vendors
# Database name: primary
#
#  id                  :uuid             not null, primary key
#  availability        :text
#  category            :string           not null
#  fit_notes           :text
#  location            :string
#  maximum_price_cents :integer
#  minimum_price_cents :integer
#  name                :string           not null
#  occasion_types      :jsonb            not null
#  preference_tags     :jsonb            not null
#  source_kind         :string           default("manual"), not null
#  source_name         :string
#  source_url          :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  user_id             :uuid             not null
#
# Indexes
#
#  index_vendors_on_occasion_types        (occasion_types) USING gin
#  index_vendors_on_preference_tags       (preference_tags) USING gin
#  index_vendors_on_user_and_lower_name   (user_id, lower((name)::text))
#  index_vendors_on_user_id               (user_id)
#  index_vendors_on_user_id_and_category  (user_id,category)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class Vendor < ApplicationRecord
  CATEGORIES = %w[
    restaurant florist bakery caterer private_chef photographer venue musician entertainer
    decorator gift_shop local_artisan spa tour_operator transportation childcare party_rental
  ].freeze
  SOURCE_KINDS = %w[manual external].freeze
  MAX_PRICE_CENTS = 2_147_483_647
  MAX_NAME_LENGTH = 200
  MAX_LOCATION_LENGTH = 200
  MAX_AVAILABILITY_LENGTH = 1_000
  MAX_FIT_NOTES_LENGTH = 2_000
  MAX_SOURCE_LENGTH = 200
  MAX_TAGS = 20
  MAX_TAG_LENGTH = 60

  belongs_to :user
  has_many :event_plan_vendors, dependent: :destroy
  has_many :event_plans, through: :event_plan_vendors

  encrypts :fit_notes

  before_validation :normalize_fields

  validates :name, presence: true, length: { maximum: MAX_NAME_LENGTH }
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :location, length: { maximum: MAX_LOCATION_LENGTH }, allow_blank: true
  validates :availability, length: { maximum: MAX_AVAILABILITY_LENGTH }, allow_blank: true
  validates :fit_notes, length: { maximum: MAX_FIT_NOTES_LENGTH }, allow_blank: true
  validates :source_kind, presence: true, inclusion: { in: SOURCE_KINDS }
  validates :source_name, presence: true, if: :external?
  validates :source_name, length: { maximum: MAX_SOURCE_LENGTH }, allow_blank: true
  validates :source_url, length: { maximum: 2_000 }, allow_blank: true
  validates :minimum_price_cents, :maximum_price_cents,
    numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_PRICE_CENTS },
    allow_nil: true
  validate :prices_are_numeric
  validate :price_range_is_ordered
  validate :source_url_is_http
  validate :tag_collections_are_bounded

  scope :ordered, -> { order(Arel.sql("lower(vendors.name)"), :id) }

  def minimum_price = formatted_price_input(minimum_price_cents)

  def minimum_price=(value)
    @minimum_price_invalid = false
    self.minimum_price_cents = parse_price_cents(value)
  rescue ArgumentError
    @minimum_price_invalid = true
    self.minimum_price_cents = nil
  end

  def maximum_price = formatted_price_input(maximum_price_cents)

  def maximum_price=(value)
    @maximum_price_invalid = false
    self.maximum_price_cents = parse_price_cents(value)
  rescue ArgumentError
    @maximum_price_invalid = true
    self.maximum_price_cents = nil
  end

  def occasion_types_text = Array(occasion_types).join(", ")

  def occasion_types_text=(value)
    self.occasion_types = split_tags(value)
  end

  def preference_tags_text = Array(preference_tags).join(", ")

  def preference_tags_text=(value)
    self.preference_tags = split_tags(value)
  end

  def external? = source_kind == "external"

  def category_label = I18n.t("vendors.categories.#{category}")

  def source_label
    source_name.presence || I18n.t("vendors.sources.#{source_kind}")
  end

  def price_range
    return if minimum_price_cents.blank? && maximum_price_cents.blank?
    return money(minimum_price_cents) if maximum_price_cents.blank?
    return I18n.t("vendors.price.up_to", amount: money(maximum_price_cents)) if minimum_price_cents.blank?

    "#{money(minimum_price_cents)}–#{money(maximum_price_cents)}"
  end

  private

  def normalize_fields
    self.name = name.to_s.squish
    self.location = location.to_s.squish.presence
    self.availability = availability.to_s.squish.presence
    self.fit_notes = fit_notes.to_s.strip.presence
    self.source_name = source_name.to_s.squish.presence
    self.source_url = source_url.to_s.strip.presence
    self.occasion_types = normalize_tags(occasion_types)
    self.preference_tags = normalize_tags(preference_tags)
  end

  def split_tags(value)
    Array(value.to_s.split(","))
  end

  def normalize_tags(values)
    Array(values).filter_map { |value| value.to_s.squish.downcase.presence }.uniq
  end

  def parse_price_cents(value)
    return nil if value.blank?

    decimal = BigDecimal(value.to_s)
    raise ArgumentError unless decimal.finite?

    (decimal * 100).round
  end

  def formatted_price_input(cents)
    return if cents.blank?

    format("%.2f", BigDecimal(cents.to_s) / 100)
  end

  def money(cents) = format("$%.2f", BigDecimal(cents.to_s) / 100)

  def prices_are_numeric
    errors.add(:minimum_price, :not_a_number) if @minimum_price_invalid
    errors.add(:maximum_price, :not_a_number) if @maximum_price_invalid
  end

  def price_range_is_ordered
    return if minimum_price_cents.blank? || maximum_price_cents.blank?
    return if minimum_price_cents <= maximum_price_cents

    errors.add(:maximum_price, :greater_than_or_equal_to, count: minimum_price)
  end

  def source_url_is_http
    return if source_url.blank?

    uri = URI.parse(source_url)
    return if uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.blank?

    errors.add(:source_url, :invalid)
  rescue URI::InvalidURIError
    errors.add(:source_url, :invalid)
  end

  def tag_collections_are_bounded
    validate_tags(:occasion_types, occasion_types, allowed: EventPlan::OCCASION_TYPES)
    validate_tags(:preference_tags, preference_tags)
  end

  def validate_tags(attribute, values, allowed: nil)
    tags = Array(values)
    errors.add(attribute, :too_long, count: MAX_TAGS) if tags.length > MAX_TAGS
    errors.add(attribute, :invalid) if tags.any? { |tag| tag.length > MAX_TAG_LENGTH || (allowed && !tag.in?(allowed)) }
  end
end
