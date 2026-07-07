# == Schema Information
#
# Table name: gifts
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  given_on                :date
#  name                    :string           not null
#  notes                   :text
#  occasion                :string
#  outcome                 :string
#  price_cents             :integer
#  reaction                :text
#  status                  :string           default("idea"), not null
#  vendor                  :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  index_gifts_on_relationship_profile_id               (relationship_profile_id)
#  index_gifts_on_relationship_profile_id_and_given_on  (relationship_profile_id,given_on)
#  index_gifts_on_relationship_profile_id_and_name      (relationship_profile_id,name)
#  index_gifts_on_relationship_profile_id_and_outcome   (relationship_profile_id,outcome)
#  index_gifts_on_relationship_profile_id_and_status    (relationship_profile_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id)
#
class Gift < ApplicationRecord
  MAX_PRICE_CENTS = 2_147_483_647
  STATUSES = %w[idea planned given archived].freeze
  EDITABLE_STATUSES = %w[idea planned].freeze
  OUTCOMES = %w[successful unsuccessful mixed unknown].freeze

  belongs_to :relationship_profile

  before_validation :normalize_text_fields

  validates :name, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :outcome, inclusion: { in: OUTCOMES }, allow_blank: true
  validates :given_on, presence: true, if: :given?
  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :price_must_be_numeric
  validate :price_must_fit_column

  scope :ordered, -> { order(Arel.sql("CASE status WHEN 'idea' THEN 0 WHEN 'planned' THEN 1 WHEN 'given' THEN 2 ELSE 3 END"), Arel.sql("given_on DESC NULLS LAST"), :name) }

  def price
    return if price_cents.blank?

    format("%.2f", price_cents / 100.0)
  end

  def price=(value)
    @invalid_price = false
    self.price_cents = parse_price_cents(value)
  rescue ArgumentError
    @invalid_price = true
    self.price_cents = nil
  end

  def status_label
    self.class.status_label(status)
  end

  def outcome_label
    return if outcome.blank?

    self.class.outcome_label(outcome)
  end

  def given?
    status == "given"
  end

  def duplicate_candidate?
    normalized_name = name.to_s.squish.downcase
    return false if relationship_profile.blank? || normalized_name.blank?

    gifts = relationship_profile.gifts
    if gifts.loaded? && gifts.any? { |gift| gift == self }
      gifts.any? { |gift| gift != self && gift.name.to_s.squish.downcase == normalized_name }
    else
      gifts.where.not(id:).where("lower(name) = ?", normalized_name).exists?
    end
  end

  def mark_given!(given_on: Date.current, reaction: nil, outcome: "unknown")
    update!(
      status: "given",
      given_on: given_on.presence || Date.current,
      reaction: reaction,
      outcome: outcome.presence || "unknown"
    )
  end

  def self.status_options
    STATUSES.map { |value| [ status_label(value), value ] }
  end

  def self.editable_status_options
    EDITABLE_STATUSES.map { |value| [ status_label(value), value ] }
  end

  def self.outcome_options
    OUTCOMES.map { |value| [ outcome_label(value), value ] }
  end

  def self.status_label(value)
    I18n.t("gifts.statuses.#{value}")
  end

  def self.outcome_label(value)
    I18n.t("gifts.outcomes.#{value}")
  end

  private

  def normalize_text_fields
    self.name = name.to_s.squish
    self.occasion = occasion.to_s.squish.presence
    self.vendor = vendor.to_s.squish.presence
    self.reaction = reaction.to_s.strip.presence
    self.notes = notes.to_s.strip.presence
  end

  def parse_price_cents(value)
    return nil if value.blank?

    decimal = BigDecimal(value.to_s)
    raise ArgumentError unless decimal.finite?

    (decimal * 100).round
  end

  def price_must_be_numeric
    errors.add(:price, :not_a_number) if @invalid_price
  end

  def price_must_fit_column
    return if price_cents.blank? || @invalid_price || price_cents <= MAX_PRICE_CENTS

    errors.add(:price, :less_than_or_equal_to, count: format("%.2f", MAX_PRICE_CENTS / 100.0))
  end
end
