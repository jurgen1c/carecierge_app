# == Schema Information
#
# Table name: audit_events
# Database name: primary
#
#  id          :uuid             not null, primary key
#  action      :string           not null
#  actor_kind  :string           not null
#  metadata    :jsonb            not null
#  occurred_at :datetime         not null
#  source      :string           not null
#  target_type :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  actor_id    :uuid
#  target_id   :uuid
#  user_id     :uuid             not null
#
# Indexes
#
#  index_audit_events_on_action_and_occurred_at     (action,occurred_at DESC)
#  index_audit_events_on_actor_id                   (actor_id)
#  index_audit_events_on_global_order               (occurred_at,created_at,id)
#  index_audit_events_on_source_and_occurred_at     (source,occurred_at DESC)
#  index_audit_events_on_target_type_and_target_id  (target_type,target_id)
#  index_audit_events_on_user_id                    (user_id)
#  index_audit_events_on_user_id_and_occurred_at    (user_id,occurred_at DESC)
#
# Foreign Keys
#
#  fk_rails_...  (actor_id => users.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class AuditEvent < ApplicationRecord
  ACTIONS = %w[
    approval.granted
    permission.changed
    sensitive_record.accessed
    data_export.requested
    data_deletion.requested
    automation.performed
    ai.memory_extracted
    message.drafted
    relationship_briefing.generated
    relationship_briefing.saved
    relationship_briefing.dismissed
    gift_recommendation.generated
    gift_recommendation.saved
    gift_recommendation.dismissed
    gift_recommendation.purchased
    event_plan.suggestions_generated
    personal_touch_checklist.created
    personal_touch_item.created
    personal_touch_item.completed
    personal_touch_item.reopened
    personal_touch_item.dismissed
    personal_touch_item.reordered
    vendor.contacted
    booking.requested
    purchase.approved
    relationship_profile.created
    relationship_profile.updated
    relationship_profile.archived
    relationship_profile.deleted
    reminder.created
    reminder.updated
    reminder.deleted
    reminder.snoozed
    reminder.completed
    privacy_vault.opened
    privacy_vault.unlock_failed
    privacy_vault.locked
    privacy_vault.viewed
    privacy_vault.protected
    privacy_vault.restored
    privacy_vault.suggestion_usage_changed
  ].freeze
  ACTOR_KINDS = %w[user ai automation system].freeze
  SOURCES = %w[web_app mobile_app ai automation system support].freeze
  SAFE_METADATA_KEYS = %w[
    capability
    changed_fields
    count
    new_mode
    permission_scope
    previous_mode
    request_kind
    result
  ].freeze
  TARGET_TYPES = %w[AutomationPermission EventPlan PrivacyVaultItem RelationshipProfile Reminder User].freeze
  MAX_METADATA_VALUE_LENGTH = 120

  belongs_to :user
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :target, polymorphic: true, optional: true

  validates :action, inclusion: { in: ACTIONS }
  validates :actor_kind, inclusion: { in: ACTOR_KINDS }
  validates :source, inclusion: { in: SOURCES }
  validates :target_type, inclusion: { in: TARGET_TYPES }, allow_nil: true
  validates :occurred_at, presence: true
  validate :actor_matches_kind
  validate :actor_can_act_for_account
  validate :metadata_is_privacy_safe
  validate :target_belongs_to_account

  scope :recent_first, -> { order(occurred_at: :desc, created_at: :desc, id: :desc) }

  def self.record!(user:, actor:, action:, source: "web_app", target: nil, actor_kind: nil, metadata: {}, occurred_at: Time.current)
    attributes = {
      user:,
      actor:,
      actor_kind: actor_kind || (actor ? "user" : source),
      action:,
      source:,
      target:,
      metadata: metadata.to_h.stringify_keys,
      occurred_at:
    }
    return create!(attributes) unless target

    transaction do
      locked_target = target.class.base_class.unscoped.lock.find(target.id)
      create!(attributes.merge(target: locked_target))
    end
  end

  def readonly?
    persisted?
  end

  private

  def actor_matches_kind
    if actor_kind == "user"
      errors.add(:actor, :blank) if actor.blank?
    elsif actor.present?
      errors.add(:actor, :invalid)
    end
  end

  def actor_can_act_for_account
    return if actor.blank? || user.blank?
    return if actor == user || actor.admin?

    errors.add(:actor, :invalid)
  end

  def metadata_is_privacy_safe
    unless metadata.is_a?(Hash)
      errors.add(:metadata, :invalid)
      return
    end

    keys = metadata.keys.map(&:to_s)
    invalid_value = metadata.values.any? do |value|
      invalid_type = !value.nil? && !value.is_a?(String) && !value.is_a?(Numeric) && value != true && value != false
      invalid_type || value.is_a?(String) && value.length > MAX_METADATA_VALUE_LENGTH
    end
    errors.add(:metadata, :invalid) if (keys - SAFE_METADATA_KEYS).any? || invalid_value
  end

  def target_belongs_to_account
    return if target_id.blank? && target_type.blank?

    unless target
      errors.add(:target, :invalid)
      return
    end

    owner_id = case target
    when User then target.id
    when RelationshipProfile, Reminder, AutomationPermission, EventPlan then target.user_id
    when PrivacyVaultItem then target.relationship_profile.user_id
    end
    errors.add(:target, :invalid) unless owner_id == user_id
  end
end
