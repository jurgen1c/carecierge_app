# == Schema Information
#
# Table name: draft_revisions
# Database name: primary
#
#  id                 :uuid             not null, primary key
#  content            :text             not null
#  context_categories :jsonb            not null
#  origin             :string           not null
#  position           :integer          not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  message_draft_id   :uuid             not null
#
# Indexes
#
#  index_draft_revisions_on_message_draft_id               (message_draft_id)
#  index_draft_revisions_on_message_draft_id_and_position  (message_draft_id,position) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (message_draft_id => message_drafts.id) ON DELETE => cascade
#
class DraftRevision < ApplicationRecord
  ORIGINS = %w[generated edited restored].freeze
  CONTEXT_CATEGORIES = %w[
    profile
    important_dates
    preferences
    public_notes
    memories
    private_notes
    vault
  ].freeze
  MAX_CONTENT_LENGTH = 10_000

  belongs_to :message_draft, inverse_of: :draft_revisions

  before_validation :normalize_content
  before_update :prevent_update

  validates :position, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :message_draft_id }
  validates :origin, inclusion: { in: ORIGINS }
  validates :content, presence: true, length: { maximum: MAX_CONTENT_LENGTH }
  validate :context_categories_are_supported

  private

  def normalize_content
    self.content = content.to_s.strip
    self.context_categories = Array(context_categories).map(&:to_s).uniq
  end

  def prevent_update
    raise ActiveRecord::ReadOnlyRecord, "Draft revisions are immutable"
  end

  def context_categories_are_supported
    return if context_categories.is_a?(Array) && (context_categories - CONTEXT_CATEGORIES).empty?

    errors.add(:context_categories, :invalid)
  end
end
