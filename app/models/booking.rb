# == Schema Information
#
# Table name: bookings
# Database name: primary
#
#  id                   :uuid             not null, primary key
#  booking_kind         :string           default("reservation"), not null
#  cancellation_policy  :text
#  confirmation_details :text
#  location             :text
#  lock_version         :integer          default(0), not null
#  notes                :text
#  provider_name        :text             not null
#  starts_at            :datetime         not null
#  status               :string           default("planned"), not null
#  time_zone            :string           default("UTC"), not null
#  title                :text             not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  event_plan_id        :uuid             not null
#  plan_task_id         :uuid
#  user_id              :uuid             not null
#
# Indexes
#
#  index_bookings_on_event_plan_id                           (event_plan_id)
#  index_bookings_on_event_plan_id_and_starts_at_and_id      (event_plan_id,starts_at,id)
#  index_bookings_on_event_plan_id_and_status_and_starts_at  (event_plan_id,status,starts_at)
#  index_bookings_on_unique_plan_task                        (plan_task_id) UNIQUE WHERE (plan_task_id IS NOT NULL)
#  index_bookings_on_user_id                                 (user_id)
#  index_bookings_on_user_id_and_created_at                  (user_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (event_plan_id => event_plans.id) ON DELETE => cascade
#  fk_rails_...  (plan_task_id => plan_tasks.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class Booking < ApplicationRecord
  BOOKING_KINDS = %w[reservation booking].freeze
  STATUSES = %w[planned requested confirmed completed cancelled].freeze
  ACTIVE_STATUSES = %w[planned requested].freeze
  TERMINAL_TASK_STATUSES = %w[confirmed completed cancelled].freeze
  MAX_TITLE_LENGTH = 200
  MAX_PROVIDER_NAME_LENGTH = 200
  MAX_LOCATION_LENGTH = 500
  MAX_CONFIRMATION_DETAILS_LENGTH = 2_000
  MAX_CANCELLATION_POLICY_LENGTH = 4_000
  MAX_NOTES_LENGTH = 4_000

  belongs_to :user
  belongs_to :event_plan
  belongs_to :plan_task, optional: true
  has_many :reminders
  has_one :timeline_entry, as: :source_record, dependent: :destroy

  encrypts :title
  encrypts :provider_name
  encrypts :location
  encrypts :confirmation_details
  encrypts :cancellation_policy
  encrypts :notes

  before_validation :normalize_fields
  before_destroy :detach_reminders

  validates :booking_kind, inclusion: { in: BOOKING_KINDS }
  validates :title, presence: true, length: { maximum: MAX_TITLE_LENGTH }
  validates :provider_name, presence: true, length: { maximum: MAX_PROVIDER_NAME_LENGTH }
  validates :starts_at, presence: true
  validates :time_zone, presence: true
  validates :location, length: { maximum: MAX_LOCATION_LENGTH }, allow_blank: true
  validates :status, inclusion: { in: STATUSES }
  validates :confirmation_details, length: { maximum: MAX_CONFIRMATION_DETAILS_LENGTH }, allow_blank: true
  validates :cancellation_policy, length: { maximum: MAX_CANCELLATION_POLICY_LENGTH }, allow_blank: true
  validates :notes, length: { maximum: MAX_NOTES_LENGTH }, allow_blank: true
  validate :recognized_time_zone
  validate :event_plan_belongs_to_user
  validate :event_plan_is_active, on: :create
  validate :plan_task_matches_event_plan

  scope :ordered, lambda {
    order(
      Arel.sql("CASE WHEN starts_at >= CURRENT_TIMESTAMP THEN 0 ELSE 1 END ASC"),
      Arel.sql("CASE WHEN starts_at >= CURRENT_TIMESTAMP THEN starts_at END ASC"),
      Arel.sql("CASE WHEN starts_at < CURRENT_TIMESTAMP THEN starts_at END DESC"),
      :created_at,
      :id
    )
  }

  BOOKING_KINDS.each { |value| define_method("#{value}?") { booking_kind == value } }
  STATUSES.each { |value| define_method("#{value}?") { status == value } }

  def mutable? = event_plan.active? && event_plan.relationship_profile.kept?
  def relationship_profile_id = event_plan&.relationship_profile_id
  def local_starts_at
    return unless starts_at

    starts_at.in_time_zone(ActiveSupport::TimeZone[time_zone] || Time.zone)
  end
  def status_label = I18n.t("bookings.statuses.#{status}")
  def booking_kind_label = I18n.t("bookings.kinds.#{booking_kind}")

  def obsolete_reminder_milestones
    case status
    when "confirmed" then [ "confirmation" ]
    when "completed", "cancelled" then Reminder::BOOKING_MILESTONES
    else []
    end
  end

  def suggested_reminder_at(milestone:, time_zone:, now: Time.current)
    zone = ActiveSupport::TimeZone[time_zone]
    return unless zone && starts_at

    local_start = starts_at.in_time_zone(zone)
    candidate = case milestone
    when "deposit" then local_start - 1.week
    when "confirmation" then local_start - 2.days
    when "arrival" then local_start - 1.hour
    when "change" then local_start - 1.day
    end
    return if candidate.blank? || local_start <= now.in_time_zone(zone)

    next_hour = (now.in_time_zone(zone) + 1.hour).change(min: 0, sec: 0)
    suggested_at = [ candidate, next_hour ].max
    suggested_at if suggested_at < local_start
  end

  private

  def normalize_fields
    self.title = title.to_s.squish
    self.provider_name = provider_name.to_s.squish
    self.location = location.to_s.squish.presence
    self.confirmation_details = confirmation_details.to_s.strip.presence
    self.cancellation_policy = cancellation_policy.to_s.strip.presence
    self.notes = notes.to_s.strip.presence
  end

  def recognized_time_zone
    errors.add(:time_zone, :invalid) if time_zone.present? && ActiveSupport::TimeZone[time_zone].blank?
  end

  def event_plan_belongs_to_user
    errors.add(:event_plan, :different_owner) if event_plan && event_plan.user_id != user_id
  end

  def event_plan_is_active
    errors.add(:event_plan, :inactive) unless event_plan&.active? && event_plan&.relationship_profile&.kept?
  end

  def plan_task_matches_event_plan
    return unless plan_task

    errors.add(:plan_task, :different_plan) if plan_task.event_plan_id != event_plan_id
  end

  def detach_reminders
    reminders.update_all(booking_id: nil, booking_milestone: nil)
  end
end
