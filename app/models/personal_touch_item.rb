# == Schema Information
#
# Table name: personal_touch_items
# Database name: primary
#
#  id                          :uuid             not null, primary key
#  category                    :string           not null
#  completed_at                :datetime
#  details                     :text
#  dismissed_at                :datetime
#  origin                      :string           default("manual"), not null
#  position                    :integer          default(0), not null
#  source_context              :text             default("[]"), not null
#  status                      :string           default("active"), not null
#  title                       :text             not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  personal_touch_checklist_id :uuid             not null
#
# Indexes
#
#  idx_personal_touch_items_checklist_status_position         (personal_touch_checklist_id,status,position)
#  index_personal_touch_items_on_personal_touch_checklist_id  (personal_touch_checklist_id)
#
# Foreign Keys
#
#  fk_rails_...  (personal_touch_checklist_id => personal_touch_checklists.id) ON DELETE => cascade
#
class PersonalTouchItem < ApplicationRecord
  CATEGORIES = %w[
    preference constraint message gift dietary_need accessibility_need logistics follow_up
  ].freeze
  ORIGINS = %w[manual suggested].freeze
  STATUSES = %w[active completed dismissed].freeze
  MAX_TITLE_LENGTH = 180
  MAX_DETAILS_LENGTH = 1_000
  MAX_SOURCES = 3
  MAX_SOURCE_ID_LENGTH = 64
  MAX_SOURCE_LABEL_LENGTH = 180
  SOURCE_KEYS = %w[certainty source_id source_label source_type].freeze
  SOURCE_CERTAINTIES = %w[confirmed inferred].freeze
  SOURCE_TYPE = "RelationshipPreference"

  enum :category, CATEGORIES.index_with(&:itself), validate: true
  enum :origin, ORIGINS.index_with(&:itself), validate: true
  enum :status, STATUSES.index_with(&:itself), validate: true

  belongs_to :personal_touch_checklist

  serialize :source_context, coder: JSON
  encrypts :title
  encrypts :details
  encrypts :source_context

  before_validation :normalize_text

  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :origin, presence: true, inclusion: { in: ORIGINS }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :title, presence: true, length: { maximum: MAX_TITLE_LENGTH }
  validates :details, length: { maximum: MAX_DETAILS_LENGTH }, allow_nil: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :source_context_is_bounded

  scope :visible, -> { where.not(status: "dismissed") }
  scope :ordered, -> { order(:position, :created_at, :id) }

  def complete!
    transition_to!("completed", completed_at: Time.current, dismissed_at: nil, from: "active")
  end

  def reopen!
    transition_to!("active", completed_at: nil, dismissed_at: nil, from: "completed")
  end

  def dismiss!
    transition_to!("dismissed", completed_at: nil, dismissed_at: Time.current, from: %w[active completed])
  end

  def move_up!
    move_toward!(direction: :up)
  end

  def move_down!
    move_toward!(direction: :down)
  end

  private

  def transition_to!(next_status, completed_at:, dismissed_at:, from:)
    personal_touch_checklist.with_mutation_lock do
      reload
      next if status == next_status
      raise ActiveRecord::RecordInvalid, self unless status.in?(Array(from))

      update!(status: next_status, completed_at:, dismissed_at:)
    end
  end

  def move_toward!(direction:)
    personal_touch_checklist.with_mutation_lock do
      reload
      scope = personal_touch_checklist.personal_touch_items.visible.where.not(id:)
      sibling = if direction == :up
        scope.where("position < ?", position).reorder(position: :desc, created_at: :desc, id: :desc).first
      else
        scope.where("position > ?", position).reorder(:position, :created_at, :id).first
      end
      next unless sibling

      current_position = position
      update!(position: sibling.position)
      sibling.update!(position: current_position)
    end
  end

  def normalize_text
    self.title = title.to_s.squish
    self.details = details.to_s.squish.presence
  end

  def source_context_is_bounded
    unless source_context.is_a?(Array) && source_context.length <= MAX_SOURCES && source_context.all? { |source| valid_source?(source) }
      errors.add(:source_context, :invalid)
    end
  end

  def valid_source?(source)
    source.is_a?(Hash) &&
      source.keys.map(&:to_s).sort == SOURCE_KEYS &&
      SOURCE_CERTAINTIES.include?(source["certainty"]) &&
      source["source_type"] == SOURCE_TYPE &&
      source["source_id"].is_a?(String) && source["source_id"].length.between?(1, MAX_SOURCE_ID_LENGTH) &&
      source["source_label"].is_a?(String) && source["source_label"].length.between?(1, MAX_SOURCE_LABEL_LENGTH)
  end
end
