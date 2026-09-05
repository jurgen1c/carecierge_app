# == Schema Information
#
# Table name: gift_purchase_plans
# Database name: primary
#
#  id                   :uuid             not null, primary key
#  budget               :decimal(12, 2)
#  constraints          :text
#  currency             :string           default("USD"), not null
#  delivery_status      :string           default("not_started"), not null
#  expected_delivery_on :date
#  follow_up_notes      :text
#  follow_up_on         :date
#  lock_version         :integer          default(0), not null
#  options              :text             not null
#  purchase_by          :date
#  purchase_status      :string           default("planning"), not null
#  shipping_notes       :text
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  gift_id              :uuid             not null
#  plan_task_id         :uuid
#
# Indexes
#
#  index_gift_purchase_plans_on_gift_id       (gift_id) UNIQUE
#  index_gift_purchase_plans_on_plan_task_id  (plan_task_id)
#
# Foreign Keys
#
#  fk_rails_...  (gift_id => gifts.id) ON DELETE => cascade
#  fk_rails_...  (plan_task_id => plan_tasks.id) ON DELETE => nullify
#
class GiftPurchasePlan < ApplicationRecord
  has_many :external_provider_actions, dependent: :destroy
  PURCHASE_STATUSES = %w[planning purchased cancelled].freeze
  DELIVERY_STATUSES = %w[not_started awaiting shipped delivered].freeze
  MILESTONES = %w[purchase delivery follow_up].freeze
  MAX_OPTIONS = 3
  MONEY_PATTERN = /\A\d{1,10}(?:\.\d{1,2})?\z/

  belongs_to :gift
  belongs_to :plan_task, optional: true

  serialize :options, coder: JSON
  encrypts :options, :shipping_notes, :constraints, :follow_up_notes

  before_validation :normalize_fields

  validates :currency, format: { with: /\A[A-Z]{3}\z/ }
  validates :purchase_status, inclusion: { in: PURCHASE_STATUSES }
  validates :delivery_status, inclusion: { in: DELIVERY_STATUSES }
  validates :shipping_notes, :constraints, :follow_up_notes, length: { maximum: 2_000 }
  validates :purchase_by, :expected_delivery_on, :follow_up_on,
    comparison: { less_than_or_equal_to: Date.new(9999, 12, 31) }, allow_nil: true
  validate :valid_budget
  validate :valid_options
  validate :matching_plan_task

  def current_plan_task
    plan_task if plan_task && !plan_task.superseded? && !plan_task.event_plan.archived?
  end

  def suggested_option
    return unless budget && valid_money?(budget_before_type_cast) && options.is_a?(Array)

    options.select do |option|
      option.is_a?(Hash) && option["constraints_checked"] == "1" && valid_money?(option["cost"]) &&
        BigDecimal(option["cost"]) <= budget
    end.min_by { |option| BigDecimal(option["cost"]) }
  end

  def milestone_date(milestone)
    { "purchase" => purchase_by, "delivery" => expected_delivery_on, "follow_up" => follow_up_on }[milestone]
  end

  def options=(value)
    value = value.values if value.is_a?(Hash)
    super(value)
  end

  private

  def normalize_fields
    self.currency = currency.to_s.strip.upcase
    %i[shipping_notes constraints follow_up_notes].each { |field| self[field] = self[field].to_s.strip.presence }
    self.options ||= []
    return unless options.is_a?(Array)

    self.options = options.filter_map do |option|
      next option unless option.is_a?(Hash)

      cleaned = option.transform_values { |value| value.to_s.strip }
      next if cleaned.except("constraints_checked").values.all?(&:blank?)

      cleaned
    end
  end

  def valid_money?(value)
    value.present? && (value.is_a?(BigDecimal) ? value.to_s("F") : value.to_s).match?(MONEY_PATTERN)
  end

  def valid_budget
    raw = budget_before_type_cast
    errors.add(:budget, :invalid) if raw.present? && !valid_money?(raw)
  end

  def valid_options
    valid = options.is_a?(Array) && options.length <= MAX_OPTIONS && options.all? do |option|
      option.is_a?(Hash) && (option.keys - %w[vendor url cost constraints_checked]).empty? &&
        option["vendor"].present? && option["vendor"].length <= 200 &&
        (option["cost"].blank? || valid_money?(option["cost"])) &&
        option["constraints_checked"].in?([ nil, "", "0", "1" ]) && safe_url?(option["url"])
    end
    errors.add(:options, :invalid) unless valid
  end

  def safe_url?(value)
    return true if value.blank?
    return false if value.length > 2_000

    uri = URI.parse(value)
    uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil?
  rescue URI::InvalidURIError
    false
  end

  def matching_plan_task
    return unless plan_task && gift

    errors.add(:plan_task, :invalid) unless plan_task.event_plan.relationship_profile_id == gift.relationship_profile_id
  end
end
