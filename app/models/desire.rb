# == Schema Information
#
# Table name: desires
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  captured_on             :date
#  category                :string           not null
#  notes                   :text
#  source                  :string           default("manual"), not null
#  status                  :string           default("active"), not null
#  title                   :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  index_desires_on_relationship_profile_id                  (relationship_profile_id)
#  index_desires_on_relationship_profile_id_and_captured_on  (relationship_profile_id,captured_on)
#  index_desires_on_relationship_profile_id_and_category     (relationship_profile_id,category)
#  index_desires_on_relationship_profile_id_and_status       (relationship_profile_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id)
#
class Desire < ApplicationRecord
  CATEGORIES = %w[gift activity experience help travel food wellness other].freeze
  STATUSES = %w[active planned fulfilled archived].freeze
  EDITABLE_STATUSES = %w[active planned].freeze
  SOURCES = %w[manual note_extraction imported].freeze
  SUGGESTION_CONTEXTS = {
    "gift" => %w[gift birthday gesture],
    "activity" => %w[date gesture],
    "experience" => %w[date birthday gesture],
    "help" => %w[gesture plan],
    "travel" => %w[date birthday gift],
    "food" => %w[date birthday gesture],
    "wellness" => %w[gift gesture],
    "other" => %w[gesture]
  }.freeze

  belongs_to :relationship_profile
  has_many :fulfillments, class_name: "DesireFulfillment", dependent: :destroy

  before_validation :normalize_text_fields
  before_validation :default_captured_on

  validates :title, presence: true
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :source, presence: true, inclusion: { in: SOURCES }

  scope :ordered, -> { order(Arel.sql("CASE status WHEN 'active' THEN 0 WHEN 'planned' THEN 1 WHEN 'fulfilled' THEN 2 ELSE 3 END"), Arel.sql("captured_on DESC NULLS LAST"), :title) }

  def category_label
    self.class.category_label(category)
  end

  def status_label
    self.class.status_label(status)
  end

  def source_label
    self.class.source_label(source)
  end

  def fulfilled?
    status == "fulfilled"
  end

  def suggestion_contexts
    SUGGESTION_CONTEXTS.fetch(category, SUGGESTION_CONTEXTS.fetch("other"))
  end

  def suggestion_context_labels
    suggestion_contexts.map { |context| self.class.suggestion_context_label(context) }
  end

  def fulfill!(fulfilled_on: Date.current, notes: nil)
    transaction do
      fulfillments.create!(fulfilled_on:, notes:)
      update!(status: "fulfilled")
    end
  end

  def self.category_options
    CATEGORIES.map { |value| [ category_label(value), value ] }
  end

  def self.status_options
    STATUSES.map { |value| [ status_label(value), value ] }
  end

  def self.editable_status_options
    EDITABLE_STATUSES.map { |value| [ status_label(value), value ] }
  end

  def self.source_options
    SOURCES.map { |value| [ source_label(value), value ] }
  end

  def self.category_label(value)
    I18n.t("desires.categories.#{value}")
  end

  def self.status_label(value)
    I18n.t("desires.statuses.#{value}")
  end

  def self.source_label(value)
    I18n.t("desires.sources.#{value}")
  end

  def self.suggestion_context_label(value)
    I18n.t("desires.suggestion_contexts.#{value}")
  end

  private

  def normalize_text_fields
    self.title = title.to_s.squish
    self.notes = notes.to_s.strip.presence
  end

  def default_captured_on
    self.captured_on ||= Date.current
  end
end
