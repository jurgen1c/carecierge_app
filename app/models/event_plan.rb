# == Schema Information
#
# Table name: event_plans
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  budget_cents            :integer
#  completed_at            :datetime
#  generation_version      :bigint           default(0), not null
#  guest_list              :text
#  lock_version            :integer          default(0), not null
#  notes                   :text
#  occasion_type           :string           not null
#  source_context          :text             not null
#  starts_on               :date
#  status                  :string           default("active"), not null
#  title                   :text             not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#  user_id                 :uuid             not null
#
# Indexes
#
#  index_event_plans_on_profile_status_and_start          (relationship_profile_id,status,starts_on)
#  index_event_plans_on_relationship_profile_id           (relationship_profile_id)
#  index_event_plans_on_user_id                           (user_id)
#  index_event_plans_on_user_id_and_status_and_starts_on  (user_id,status,starts_on)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class EventPlan < ApplicationRecord
  OCCASION_TYPES = %w[
    birthday anniversary graduation baby_shower retirement promotion family_reunion
    date_night childrens_party holiday_event apology custom
  ].freeze
  STATUSES = %w[active completed archived].freeze
  MAX_TITLE_LENGTH = 200
  MAX_NOTES_LENGTH = 4_000
  MAX_GUEST_LIST_LENGTH = 4_000
  MAX_SOURCES = 40
  MAX_BUDGET_CENTS = 2_147_483_647

  belongs_to :user
  belongs_to :relationship_profile
  has_one :personal_touch_checklist, dependent: :destroy
  has_many :plan_tasks, -> { ordered }, dependent: :destroy
  has_many :backup_plans, -> { recent_first }, dependent: :destroy
  has_many :reminders, dependent: :destroy
  has_many :targeted_audit_events, as: :target, class_name: "AuditEvent", dependent: :nullify

  serialize :source_context, coder: JSON
  encrypts :title
  encrypts :guest_list
  encrypts :notes
  encrypts :source_context

  before_validation :normalize_fields

  validates :title, presence: true, length: { maximum: MAX_TITLE_LENGTH }
  validates :occasion_type, inclusion: { in: OCCASION_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :budget_cents,
    numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_BUDGET_CENTS },
    allow_nil: true
  validates :notes, length: { maximum: MAX_NOTES_LENGTH }, allow_blank: true
  validates :guest_list, length: { maximum: MAX_GUEST_LIST_LENGTH }, allow_blank: true
  validate :relationship_profile_belongs_to_user
  validate :source_context_is_supported
  validate :birthday_origin_requires_birthday_occasion

  scope :visible, -> { where.not(status: "archived") }
  scope :for_active_relationships, -> { joins(:relationship_profile).merge(RelationshipProfile.active) }
  scope :ordered, -> { order(Arel.sql("starts_on ASC NULLS LAST"), created_at: :desc, id: :desc) }

  STATUSES.each { |value| define_method("#{value}?") { status == value } }

  def progress
    tasks = plan_tasks.reject(&:superseded?)
    total = tasks.length
    completed = tasks.count(&:completed?)
    { completed:, total:, percentage: total.zero? ? 0 : ((completed * 100.0) / total).floor }
  end

  def outstanding_decisions
    plan_tasks.select { |task| task.kind == "decision" && !task.completed? && !task.superseded? }
  end

  def next_action
    plan_tasks.current.incomplete
      .reorder(Arel.sql("due_on ASC NULLS LAST"), :position, :created_at, :id)
      .first
  end

  def complete!(at: Time.current)
    with_transition_locks do
      return if completed?
      raise ActiveRecord::RecordInvalid, self unless active?

      update!(status: "completed", completed_at: at, generation_version: generation_version + 1)
      reminders.active.find_each { |reminder| reminder.retire!(at:) }
    end
  end

  def reopen!
    with_transition_locks do
      return if active?
      raise ActiveRecord::RecordInvalid, self unless completed?

      update!(status: "active", completed_at: nil, generation_version: generation_version + 1)
    end
  end

  def archive!(at: Time.current)
    with_transition_locks do
      return if archived?

      update!(status: "archived", completed_at: nil, generation_version: generation_version + 1)
      reminders.active.find_each { |reminder| reminder.retire!(at:) }
    end
  end

  def occasion_type_label = I18n.t("event_plans.occasion_types.#{occasion_type}")

  def birthday_origin_context
    Array(source_context).select do |source|
      source.is_a?(Hash) && source["role"] == "birthday_origin" && source["id"].to_s.start_with?("important_date:")
    end
  end

  def birthday_origin? = birthday_origin_context.any?

  def with_active_relationship_lock
    relationship_profile.with_lock do
      raise ActiveRecord::RecordNotFound unless relationship_profile.kept?

      yield
    end
  end

  def with_mutation_lock
    with_active_relationship_lock do
      with_lock do
        raise ActiveRecord::RecordNotFound if archived?

        yield
      end
    end
  end

  private

  def with_transition_locks
    with_active_relationship_lock do
      with_lock { yield }
    end
  end

  def normalize_fields
    self.title = title.to_s.squish
    self.notes = notes.to_s.strip.presence
    self.guest_list = guest_list.to_s.strip.presence
    self.source_context ||= []
  end

  def relationship_profile_belongs_to_user
    return if user.blank? || relationship_profile.blank?
    return if relationship_profile.user_id == user_id

    errors.add(:relationship_profile, :owner_mismatch)
  end

  def source_context_is_supported
    valid = source_context.is_a?(Array) && source_context.length <= MAX_SOURCES && source_context.all? do |source|
      source.is_a?(Hash) && source["id"].is_a?(String) && source["label"].is_a?(String)
    end
    errors.add(:source_context, :invalid) unless valid
  end

  def birthday_origin_requires_birthday_occasion
    errors.add(:occasion_type, :birthday_origin_immutable) if birthday_origin? && occasion_type != "birthday"
  end
end
