class SharedItem < ApplicationRecord
  KINDS = %w[plan date task reminder note].freeze
  EDITING_RULES = %w[creator participants].freeze

  belongs_to :shared_relationship_space
  belongs_to :creator, class_name: "User"
  belongs_to :assignee, class_name: "User", optional: true
  belongs_to :parent, class_name: "SharedItem", optional: true
  has_many :children, class_name: "SharedItem", foreign_key: :parent_id, dependent: :nullify, inverse_of: :parent
  has_many :shared_reminder_subscriptions, dependent: :destroy
  has_many :notification_events, as: :record, class_name: "Noticed::Event", dependent: :destroy

  encrypts :title, :details
  normalizes :title, with: ->(value) { value.to_s.strip }

  validates :title, presence: true, length: { maximum: 160 }
  validates :details, length: { maximum: 5_000 }
  validates :kind, inclusion: { in: KINDS }
  validates :editing, inclusion: { in: EDITING_RULES }
  validates :due_at, presence: true, if: -> { kind.in?(%w[date reminder]) }
  validate :valid_space_context
  validate :recognized_time_zone

  scope :ordered, -> { reorder(Arel.sql("completed_at ASC NULLS FIRST, due_at ASC NULLS LAST, created_at ASC, id ASC")) }

  def editable_by?(user)
    shared_relationship_space.active? && shared_relationship_space.participant?(user) &&
      (creator_id == user.id || editing == "participants")
  end

  def completed? = completed_at.present?
  def scheduled_local
    due_at&.in_time_zone(ActiveSupport::TimeZone[time_zone] || "UTC")&.strftime("%Y-%m-%dT%H:%M")
  end

  def scheduled_local=(value)
    if value.blank?
      self.due_at = nil
    else
      raise ArgumentError unless value.match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?\z/)
      local = DateTime.iso8601(value)
      self.due_at = Time.find_zone!(time_zone).local(local.year, local.month, local.day, local.hour, local.minute, local.second)
    end
  rescue ArgumentError
    errors.add(:due_at, :invalid)
    @invalid_schedule = true
  end

  private

  def valid_space_context
    space = shared_relationship_space
    errors.add(:base, :invalid) unless space&.active? && space.participant?(creator)
    errors.add(:assignee, :invalid) if assignee && (!space&.participant?(assignee) || kind != "task")
    if parent && (parent.shared_relationship_space_id != shared_relationship_space_id || parent.kind != "plan" || parent_id == id || kind == "plan")
      errors.add(:parent, :invalid)
    end
    errors.add(:due_at, :invalid) if @invalid_schedule
  end

  def recognized_time_zone
    errors.add(:time_zone, :invalid) unless ActiveSupport::TimeZone[time_zone]
  end
end
