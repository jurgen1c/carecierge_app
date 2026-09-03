# == Schema Information
#
# Table name: reminders
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  completed_at            :datetime
#  next_delivery_at        :datetime
#  notes                   :text
#  priority                :string           default("normal"), not null
#  recurrence              :string           default("none"), not null
#  recurrence_anchor_at    :datetime         not null
#  reminder_type           :string           default("custom"), not null
#  scheduled_at            :datetime         not null
#  snoozed_until           :datetime
#  status                  :string           default("active"), not null
#  time_zone               :string           default("UTC"), not null
#  title                   :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  commitment_id           :uuid
#  event_plan_id           :uuid
#  important_date_id       :uuid
#  plan_task_id            :uuid
#  relationship_profile_id :uuid
#  user_id                 :uuid             not null
#  vendor_quote_id         :uuid
#
# Indexes
#
#  index_reminders_on_active_next_delivery_at              (next_delivery_at) WHERE (((status)::text = 'active'::text) AND (next_delivery_at IS NOT NULL))
#  index_reminders_on_commitment_id                        (commitment_id)
#  index_reminders_on_event_plan_id                        (event_plan_id)
#  index_reminders_on_important_date_id                    (important_date_id)
#  index_reminders_on_plan_task_id                         (plan_task_id)
#  index_reminders_on_profile_status_and_schedule          (relationship_profile_id,status,scheduled_at)
#  index_reminders_on_relationship_profile_id              (relationship_profile_id)
#  index_reminders_on_user_id                              (user_id)
#  index_reminders_on_user_id_and_status_and_scheduled_at  (user_id,status,scheduled_at)
#  index_reminders_on_vendor_quote_id                      (vendor_quote_id)
#
# Foreign Keys
#
#  fk_rails_...  (commitment_id => commitments.id) ON DELETE => cascade
#  fk_rails_...  (event_plan_id => event_plans.id) ON DELETE => cascade
#  fk_rails_...  (important_date_id => important_dates.id) ON DELETE => nullify
#  fk_rails_...  (plan_task_id => plan_tasks.id) ON DELETE => nullify
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#  fk_rails_...  (vendor_quote_id => vendor_quotes.id) ON DELETE => nullify
#
class Reminder < ApplicationRecord
  include FeedItemStateSource

  REMINDER_TYPES = %w[birthday gift_planning check_in promise_follow_up event_preparation post_event_follow_up relationship_goal custom].freeze
  PRIORITIES = %w[low normal high].freeze
  RECURRENCES = %w[none daily weekly monthly yearly].freeze
  STATUSES = %w[active completed].freeze

  belongs_to :user
  belongs_to :relationship_profile, optional: true
  belongs_to :important_date, optional: true
  belongs_to :commitment, optional: true
  belongs_to :event_plan, optional: true
  belongs_to :plan_task, optional: true
  belongs_to :vendor_quote, optional: true

  has_many :reminder_deliveries, dependent: :destroy
  has_many :noticed_events, as: :record, class_name: "Noticed::Event", dependent: :destroy
  has_many :targeted_audit_events, as: :target, class_name: "AuditEvent", dependent: :nullify

  normalizes :title, with: -> { _1.strip }
  normalizes :notes, with: -> { _1.strip.presence }

  validates :title, :scheduled_at, :recurrence_anchor_at, presence: true
  validates :reminder_type, inclusion: { in: REMINDER_TYPES }
  validates :priority, inclusion: { in: PRIORITIES }
  validates :recurrence, inclusion: { in: RECURRENCES }
  validates :status, inclusion: { in: STATUSES }
  validate :recognized_time_zone
  validate :associations_belong_to_user
  validate :important_date_matches_relationship
  validate :commitment_matches_relationship
  validate :event_planning_context_matches_owner_and_relationship
  validate :vendor_quote_matches_owner_and_plan

  before_validation :initialize_next_delivery_at, on: :create
  before_validation :refresh_recurrence_anchor
  before_validation :reset_delivery_after_schedule_change, on: :update

  scope :active, -> { where(status: "active") }
  scope :by_effective_delivery, -> { order(Arel.sql("COALESCE(snoozed_until, scheduled_at) ASC"), :title, :id) }
  scope :ordered, -> { order(:scheduled_at, :title, :id) }
  scope :due, ->(at = Time.current) { active.where(next_delivery_at: ..at) }

  def active?
    status == "active"
  end

  def completed?
    status == "completed"
  end

  def overdue?(at = Time.current)
    active? && effective_delivery_at < at
  end

  def effective_delivery_at
    (snoozed_until || scheduled_at).in_time_zone(time_zone)
  end

  def active_relationship_profile_id
    relationship_profile_id if relationship_profile&.kept?
  end

  def due_today?(at = Time.current)
    effective_delivery_at.to_date == at.in_time_zone(time_zone).to_date
  end

  def upcoming?(at = Time.current)
    effective_delivery_at.to_date > at.in_time_zone(time_zone).to_date
  end

  def local_scheduled_at
    scheduled_at&.in_time_zone(ActiveSupport::TimeZone[time_zone] || Time.zone)
  end

  def snooze!(until_time:)
    raise ArgumentError, "Snooze time must be in the future" unless until_time.present? && until_time > Time.current
    raise ActiveRecord::RecordInvalid, self unless active?

    with_lock do
      raise ActiveRecord::RecordInvalid, self unless active?

      update!(snoozed_until: until_time, next_delivery_at: until_time)
    end
  end

  def complete!(at: Time.current)
    with_lock do
      if recurrence == "none"
        update!(status: "completed", completed_at: at, snoozed_until: nil, next_delivery_at: nil)
      else
        next_occurrence = next_occurrence_after(at)
        @advancing_recurrence = true
        begin
          update!(scheduled_at: next_occurrence, next_delivery_at: next_occurrence, snoozed_until: nil, completed_at: nil)
        ensure
          @advancing_recurrence = false
        end
      end
    end
  end

  def retire!(at: Time.current)
    with_lock do
      return if completed?

      update!(status: "completed", completed_at: at, snoozed_until: nil, next_delivery_at: nil)
    end
  end

  def self.reminder_type_options
    REMINDER_TYPES.map { |value| [ I18n.t("reminders.types.#{value}"), value ] }
  end

  def self.priority_options
    PRIORITIES.map { |value| [ I18n.t("reminders.priorities.#{value}"), value ] }
  end

  def self.recurrence_options
    RECURRENCES.map { |value| [ I18n.t("reminders.recurrences.#{value}"), value ] }
  end

  def reminder_type_label = I18n.t("reminders.types.#{reminder_type}")
  def priority_label = I18n.t("reminders.priorities.#{priority}")
  def recurrence_label = I18n.t("reminders.recurrences.#{recurrence}")

  private

  def recognized_time_zone
    errors.add(:time_zone, :invalid) if time_zone.blank? || ActiveSupport::TimeZone[time_zone].blank?
  end

  def associations_belong_to_user
    if relationship_profile.present? && relationship_profile.user_id != user_id
      errors.add(:relationship_profile, :different_owner)
    end

    if important_date.present? && important_date.relationship_profile.user_id != user_id
      errors.add(:important_date, :different_owner)
    end

    if commitment.present? && commitment.relationship_profile.user_id != user_id
      errors.add(:commitment, :different_owner)
    end
  end

  def important_date_matches_relationship
    return if important_date.blank? || relationship_profile.blank?
    return if important_date.relationship_profile_id == relationship_profile_id

    errors.add(:important_date, :different_relationship)
  end

  def commitment_matches_relationship
    return if commitment.blank? || relationship_profile.blank?
    return if commitment.relationship_profile_id == relationship_profile_id

    errors.add(:commitment, :different_relationship)
  end

  def event_planning_context_matches_owner_and_relationship
    if event_plan.present?
      errors.add(:event_plan, :different_owner) if event_plan.user_id != user_id
      if relationship_profile.present? && event_plan.relationship_profile_id != relationship_profile_id
        errors.add(:event_plan, :different_relationship)
      end
      if planning_attachment_added_or_changed? && !event_plan.active?
        errors.add(:event_plan, :inactive)
      end
    end

    return if plan_task.blank?

    errors.add(:plan_task, :different_plan) if event_plan.blank? || plan_task.event_plan_id != event_plan_id
    errors.add(:plan_task, :completed) if planning_attachment_added_or_changed? && plan_task.completed?
    errors.add(:plan_task, :superseded) if planning_attachment_added_or_changed? && plan_task.superseded?
  end

  def vendor_quote_matches_owner_and_plan
    return if vendor_quote.blank?

    errors.add(:vendor_quote, :different_owner) if vendor_quote.user_id != user_id
    errors.add(:vendor_quote, :different_plan) if event_plan.blank? || vendor_quote.event_plan_id != event_plan_id
  end

  def planning_attachment_added_or_changed?
    new_record? ||
      will_save_change_to_event_plan_id? && event_plan_id.present? ||
      will_save_change_to_plan_task_id? && plan_task_id.present? ||
      will_save_change_to_vendor_quote_id? && vendor_quote_id.present?
  end

  def initialize_next_delivery_at
    self.next_delivery_at ||= scheduled_at if active?
  end

  def refresh_recurrence_anchor
    return unless recurrence_anchor_at.blank? || (will_save_change_to_scheduled_at? && !@advancing_recurrence)

    self.recurrence_anchor_at = scheduled_at
  end

  def reset_delivery_after_schedule_change
    return unless will_save_change_to_scheduled_at?

    self.snoozed_until = nil
    self.next_delivery_at = active? ? scheduled_at : nil
  end

  def next_occurrence_after(reference_time)
    anchor = recurrence_anchor_at.in_time_zone(time_zone)
    interval = 1
    occurrence = advance_occurrence(anchor, interval)
    local_reference_time = reference_time.in_time_zone(time_zone)
    while occurrence <= local_reference_time
      interval += 1
      occurrence = advance_occurrence(anchor, interval)
    end
    occurrence
  end

  def advance_occurrence(anchor, interval)
    case recurrence
    when "daily" then anchor.advance(days: interval)
    when "weekly" then anchor.advance(weeks: interval)
    when "monthly" then anchor.advance(months: interval)
    when "yearly" then anchor.advance(years: interval)
    else anchor
    end
  end
end
