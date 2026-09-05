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
class VendorQuote < ApplicationRecord
  has_many :external_provider_actions, dependent: :destroy
  STATUSES = %w[draft awaiting_response received under_review accepted declined expired].freeze
  OPEN_STATUSES = %w[draft awaiting_response received under_review].freeze
  MAX_AMOUNT_CENTS = 2_147_483_647
  MAX_SCOPE_LENGTH = 4_000
  MAX_NEXT_ACTION_LENGTH = 1_000
  MAX_NOTES_LENGTH = 4_000

  belongs_to :user
  belongs_to :event_plan
  belongs_to :vendor
  has_many :reminders, dependent: :nullify

  encrypts :scope_details
  encrypts :next_action
  encrypts :notes

  before_validation :normalize_fields

  validates :amount_cents,
    numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_AMOUNT_CENTS },
    allow_nil: true
  validates :currency, format: { with: /\A[A-Z]{3}\z/ }
  validates :scope_details, presence: true, length: { maximum: MAX_SCOPE_LENGTH }
  validates :status, inclusion: { in: STATUSES }
  validates :next_action, length: { maximum: MAX_NEXT_ACTION_LENGTH }, allow_blank: true
  validates :notes, length: { maximum: MAX_NOTES_LENGTH }, allow_blank: true
  validate :amount_is_numeric
  validate :associations_belong_to_user
  validate :decision_precedes_expiration
  validate :context_is_active, on: :create

  scope :ordered, -> { order(Arel.sql("expires_on ASC NULLS LAST"), created_at: :desc, id: :desc) }

  def amount = formatted_amount_input

  def amount=(value)
    @amount_invalid = false
    @amount_precision_invalid = false
    self.amount_cents = parse_amount_cents(value)
  rescue ArgumentError
    @amount_invalid = true
    self.amount_cents = nil
  end

  def display_status(as_of: OwnerLocalCalendar.date_for(user:))
    return "expired" if status.in?(OPEN_STATUSES) && expires_on&.<(as_of)

    status
  end

  def next_deadline_on(as_of: OwnerLocalCalendar.date_for(user:))
    [ decision_due_on, expires_on ].compact.select { |date| date >= as_of }.min
  end

  def mutable?
    event_plan.active? && event_plan.relationship_profile.kept?
  end

  def save_with_context_lock!
    with_context_locks do
      vendor.lock!
      save!
    end
  end

  def update_details!(attributes, expected_lock_version:)
    with_context_locks do
      with_lock do
        raise ActiveRecord::StaleObjectError.new(self, "update") if lock_version != expected_lock_version

        raise ActiveRecord::RecordNotFound unless mutable?
        update!(attributes.except(:lock_version))
      end
    end
  end

  def remove!
    with_context_locks(require_mutable: false) { with_lock { destroy! } }
  end

  private

  def with_context_locks(require_mutable: true)
    user.with_lock("FOR NO KEY UPDATE") do
      event_plan.relationship_profile.with_lock do
        event_plan.with_lock do
          raise ActiveRecord::RecordNotFound if require_mutable && !mutable?

          yield
        end
      end
    end
  end

  def normalize_fields
    self.currency = currency.to_s.strip.upcase
    self.scope_details = scope_details.to_s.strip.presence
    self.next_action = next_action.to_s.squish.presence
    self.notes = notes.to_s.strip.presence
  end

  def parse_amount_cents(value)
    return if value.blank?

    decimal = BigDecimal(normalized_amount_input(value))
    raise ArgumentError unless decimal.finite?

    scaled_amount = decimal * 100
    unless scaled_amount.frac.zero?
      @amount_precision_invalid = true
      return
    end

    scaled_amount.to_i
  end

  def normalized_amount_input(value)
    input = value.to_s.strip

    if I18n.locale == :es
      return input unless input.include?(",") || input.match?(/\A[+-]?\d{1,3}(?:\.\d{3})+\z/)
      return input.delete(".") unless input.include?(",")

      raise ArgumentError unless input.match?(/\A[+-]?(?:\d+|\d{1,3}(?:\.\d{3})+),\d+\z/)
      input.delete(".").sub(",", ".")
    else
      return input unless input.include?(",")

      raise ArgumentError unless input.match?(/\A[+-]?\d{1,3}(?:,\d{3})+(?:\.\d+)?\z/)

      input.delete(",")
    end
  end

  def formatted_amount_input
    return if amount_cents.blank?

    format("%.2f", BigDecimal(amount_cents.to_s) / 100)
  end

  def amount_is_numeric
    errors.add(:amount, :blank) if amount_cents.nil? && !@amount_invalid && !@amount_precision_invalid
    errors.add(:amount, :not_a_number) if @amount_invalid
    errors.add(:amount, :invalid_scale) if @amount_precision_invalid
  end

  def associations_belong_to_user
    errors.add(:event_plan, :different_owner) if event_plan && event_plan.user_id != user_id
    errors.add(:vendor, :different_owner) if vendor && vendor.user_id != user_id
  end

  def decision_precedes_expiration
    return if decision_due_on.blank? || expires_on.blank? || decision_due_on <= expires_on

    errors.add(:decision_due_on, :after_expiration)
  end

  def context_is_active
    errors.add(:event_plan, :inactive) unless event_plan&.active?
    errors.add(:relationship_profile, :inactive) unless event_plan&.relationship_profile&.kept?
  end
end
