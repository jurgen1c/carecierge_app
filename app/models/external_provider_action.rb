# An owner-authored observation. Saving this record never executes a provider action.
# == Schema Information
#
# Table name: external_provider_actions
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  action_kind             :string           not null
#  external_reference      :text
#  failure_details         :text
#  lock_version            :integer          default(0), not null
#  provider_kind           :string           not null
#  provider_name           :text             not null
#  recorded_at             :datetime         not null
#  source_label            :text             not null
#  source_url              :text
#  status                  :string           default("pending"), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  booking_id              :uuid
#  event_plan_id           :uuid
#  gift_purchase_plan_id   :uuid
#  relationship_profile_id :uuid             not null
#  reminder_id             :uuid
#  user_id                 :uuid             not null
#  vendor_quote_id         :uuid
#
# Indexes
#
#  index_external_provider_actions_on_booking_id               (booking_id)
#  index_external_provider_actions_on_event_plan_id            (event_plan_id)
#  index_external_provider_actions_on_gift_purchase_plan_id    (gift_purchase_plan_id)
#  index_external_provider_actions_on_relationship_profile_id  (relationship_profile_id)
#  index_external_provider_actions_on_reminder_id              (reminder_id)
#  index_external_provider_actions_on_user_id                  (user_id)
#  index_external_provider_actions_on_vendor_quote_id          (vendor_quote_id)
#  index_provider_actions_on_profile_history                   (relationship_profile_id,created_at,id)
#
# Foreign Keys
#
#  fk_rails_...  (booking_id => bookings.id) ON DELETE => cascade
#  fk_rails_...  (event_plan_id => event_plans.id) ON DELETE => cascade
#  fk_rails_...  (gift_purchase_plan_id => gift_purchase_plans.id) ON DELETE => cascade
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#  fk_rails_...  (reminder_id => reminders.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#  fk_rails_...  (vendor_quote_id => vendor_quotes.id) ON DELETE => cascade
#
class ExternalProviderAction < ApplicationRecord
  PROVIDER_KINDS = %w[commerce booking vendor reservation].freeze
  ACTION_KINDS = %w[purchase booking quote logistics].freeze
  STATUSES = %w[pending confirmed completed cancelled failed].freeze
  CONTEXTS = %i[gift_purchase_plan event_plan booking vendor_quote reminder].freeze

  belongs_to :user
  belongs_to :relationship_profile
  CONTEXTS.each { |context| belongs_to context, optional: true }

  encrypts :provider_name, :source_label, :source_url, :external_reference, :failure_details

  before_validation :normalize_fields
  validates :provider_name, :source_label, presence: true, length: { maximum: 200 }
  validates :source_url, :external_reference, length: { maximum: 2_000 }
  validates :failure_details, length: { maximum: 4_000 }
  validates :failure_details, presence: true, if: -> { status == "failed" }
  validates :provider_kind, inclusion: { in: PROVIDER_KINDS }
  validates :action_kind, inclusion: { in: ACTION_KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :recorded_at, presence: true
  validate :safe_source_url
  validate :owned_relationship_and_contexts

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  def mutable? = relationship_profile&.kept?

  def self.context_scope(profile, context)
    case context.to_sym
    when :gift_purchase_plan then GiftPurchasePlan.joins(:gift).where(gifts: { relationship_profile_id: profile.id })
    when :event_plan then profile.event_plans
    when :booking then profile.user.bookings.joins(:event_plan).where(event_plans: { relationship_profile_id: profile.id })
    when :vendor_quote then profile.user.vendor_quotes.joins(:event_plan).where(event_plans: { relationship_profile_id: profile.id })
    when :reminder then profile.user.reminders.where(relationship_profile_id: profile.id)
    else raise ArgumentError, "Unsupported provider context"
    end
  end

  private

  def normalize_fields
    %i[provider_name source_label source_url external_reference failure_details].each do |field|
      self[field] = self[field].to_s.strip.presence
    end
    self.failure_details = nil unless status == "failed"
  end

  def safe_source_url
    return if source_url.blank?

    uri = URI.parse(source_url)
    errors.add(:source_url, :invalid) unless uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil?
  rescue URI::InvalidURIError
    errors.add(:source_url, :invalid)
  end

  def owned_relationship_and_contexts
    unless relationship_profile && relationship_profile.user_id == user_id
      errors.add(:relationship_profile, :invalid)
      return
    end
    CONTEXTS.each do |context|
      id = public_send("#{context}_id")
      next if id.blank?

      errors.add(context, :invalid) unless self.class.context_scope(relationship_profile, context).exists?(id:)
    end
    linked_plans = [ event_plan_id, gift_purchase_plan&.plan_task&.event_plan_id, booking&.event_plan_id, vendor_quote&.event_plan_id, reminder&.event_plan_id ].compact.uniq
    errors.add(:event_plan, :invalid) if linked_plans.length > 1
  end
end
