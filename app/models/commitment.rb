# == Schema Information
#
# Table name: commitments
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  completed_at            :datetime
#  due_on                  :date
#  notes                   :text
#  status                  :string           default("open"), not null
#  title                   :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  idx_on_relationship_profile_id_status_due_on_109b7b7dd5  (relationship_profile_id,status,due_on)
#  index_commitments_on_open_due_on                         (status,due_on) WHERE (((status)::text = 'open'::text) AND (due_on IS NOT NULL))
#  index_commitments_on_relationship_profile_id             (relationship_profile_id)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#
class Commitment < ApplicationRecord
  STATUSES = %w[open completed canceled].freeze

  belongs_to :relationship_profile
  has_many :reminders, dependent: :destroy
  has_one :timeline_entry, as: :source_record, dependent: :destroy

  before_validation :normalize_text_fields

  validates :title, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :ordered, -> {
    order(
      Arel.sql("CASE status WHEN 'open' THEN 0 WHEN 'completed' THEN 1 ELSE 2 END"),
      Arel.sql("due_on ASC NULLS LAST"),
      :title,
      :id
    )
  }
  scope :overdue, ->(as_of = Date.current) { where(status: "open").where(due_on: ...as_of).order(:due_on, :title, :id) }

  STATUSES.each { |value| define_method("#{value}?") { status == value } }

  def overdue?(as_of = Date.current)
    open? && due_on.present? && due_on < as_of
  end

  def complete!(at: Time.current)
    with_lock do
      raise ActiveRecord::RecordInvalid, self unless open?

      update!(status: "completed", completed_at: at)
      retire_active_reminders!(at:)
    end
  end

  def cancel!(at: Time.current)
    with_lock do
      raise ActiveRecord::RecordInvalid, self unless open?

      update!(status: "canceled", completed_at: nil)
      retire_active_reminders!(at:)
    end
  end

  def reopen!
    with_lock do
      raise ActiveRecord::RecordInvalid, self if open?

      update!(status: "open", completed_at: nil)
    end
  end

  def status_label = self.class.status_label(status)

  def self.status_label(value)
    I18n.t("commitments.statuses.#{value}")
  end

  private

  def retire_active_reminders!(at:)
    reminders.active.find_each { |reminder| reminder.retire!(at:) }
  end

  def normalize_text_fields
    self.title = title.to_s.squish
    self.notes = notes.to_s.strip.presence
  end
end
