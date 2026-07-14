# == Schema Information
#
# Table name: important_dates
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  date_type               :string           not null
#  importance_level        :string           default("normal"), not null
#  notes                   :text
#  recurrence              :string           default("none"), not null
#  reminder_schedule       :string           default("none"), not null
#  starts_on               :date             not null
#  title                   :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  idx_on_relationship_profile_id_importance_level_a07d6afa11      (relationship_profile_id,importance_level)
#  index_important_dates_on_relationship_profile_id                (relationship_profile_id)
#  index_important_dates_on_relationship_profile_id_and_date_type  (relationship_profile_id,date_type)
#  index_important_dates_on_relationship_profile_id_and_starts_on  (relationship_profile_id,starts_on)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id)
#
class ImportantDate < ApplicationRecord
  has_many :reminders, dependent: :nullify
  DATE_TYPES = %w[birthday anniversary milestone appointment holiday custom].freeze
  RECURRENCES = %w[none yearly monthly weekly].freeze
  IMPORTANCE_LEVELS = %w[low normal high essential].freeze
  REMINDER_SCHEDULES = %w[none day_before week_before two_weeks_before month_before custom].freeze

  belongs_to :relationship_profile

  before_validation :normalize_text_fields

  validates :date_type, presence: true, inclusion: { in: DATE_TYPES }
  validates :starts_on, presence: true
  validates :recurrence, presence: true, inclusion: { in: RECURRENCES }
  validates :importance_level, presence: true, inclusion: { in: IMPORTANCE_LEVELS }
  validates :reminder_schedule, presence: true, inclusion: { in: REMINDER_SCHEDULES }

  scope :ordered, -> { order(:starts_on, :created_at) }

  def display_title
    title.presence || date_type_label
  end

  def date_type_label
    self.class.date_type_label(date_type)
  end

  def recurrence_label
    self.class.recurrence_label(recurrence)
  end

  def importance_level_label
    self.class.importance_level_label(importance_level)
  end

  def reminder_schedule_label
    self.class.reminder_schedule_label(reminder_schedule)
  end

  def next_occurrence_on(as_of: Date.current)
    return if starts_on.blank?

    reference_date = as_of.to_date
    return starts_on if starts_on >= reference_date

    case recurrence
    when "none"
      nil
    when "yearly"
      yearly_occurrence_on_or_after(reference_date)
    when "monthly"
      monthly_occurrence_on_or_after(reference_date)
    when "weekly"
      weekly_occurrence_on_or_after(reference_date)
    end
  end

  def days_until(as_of: Date.current)
    occurrence = next_occurrence_on(as_of:)
    return unless occurrence

    (occurrence - as_of.to_date).to_i
  end

  def planning_opportunity?(as_of: Date.current)
    days = days_until(as_of:)
    return false if days.nil? || days.negative?

    days <= planning_window_days
  end

  def planning_prompt(as_of: Date.current)
    return unless planning_opportunity?(as_of:)

    I18n.t("important_dates.planning_prompts.#{date_type}", default: :"important_dates.planning_prompts.default")
  end

  def self.date_type_options
    DATE_TYPES.map { |value| [ date_type_label(value), value ] }
  end

  def self.recurrence_options
    RECURRENCES.map { |value| [ recurrence_label(value), value ] }
  end

  def self.importance_level_options
    IMPORTANCE_LEVELS.map { |value| [ importance_level_label(value), value ] }
  end

  def self.reminder_schedule_options
    REMINDER_SCHEDULES.map { |value| [ reminder_schedule_label(value), value ] }
  end

  def self.date_type_label(value)
    I18n.t("important_dates.date_types.#{value}")
  end

  def self.recurrence_label(value)
    I18n.t("important_dates.recurrences.#{value}")
  end

  def self.importance_level_label(value)
    I18n.t("important_dates.importance_levels.#{value}")
  end

  def self.reminder_schedule_label(value)
    I18n.t("important_dates.reminder_schedules.#{value}")
  end

  private

  def normalize_text_fields
    self.title = title.to_s.strip.presence
    self.notes = notes.to_s.strip.presence
  end

  def planning_window_days
    return 7 if date_type == "appointment"

    30
  end

  def yearly_occurrence_on_or_after(reference_date)
    occurrence = safe_date(reference_date.year, starts_on.month, starts_on.day)
    occurrence < reference_date ? safe_date(reference_date.year + 1, starts_on.month, starts_on.day) : occurrence
  end

  def monthly_occurrence_on_or_after(reference_date)
    occurrence = safe_date(reference_date.year, reference_date.month, starts_on.day)
    occurrence = occurrence.next_month if occurrence < reference_date
    occurrence
  end

  def weekly_occurrence_on_or_after(reference_date)
    return starts_on if starts_on >= reference_date

    starts_on + (((reference_date - starts_on).to_i + 6) / 7 * 7)
  end

  def safe_date(year, month, day)
    Date.new(year, month, [ day, Time.days_in_month(month, year) ].min)
  end
end
