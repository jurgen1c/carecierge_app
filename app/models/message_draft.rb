# == Schema Information
#
# Table name: message_drafts
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  draft_type              :string           not null
#  formality               :string           default("balanced"), not null
#  response_length         :string           default("medium"), not null
#  situation               :text             default(""), not null
#  tone                    :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#  user_id                 :uuid             not null
#
# Indexes
#
#  index_message_drafts_on_relationship_profile_id  (relationship_profile_id) UNIQUE
#  index_message_drafts_on_user_id                  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class MessageDraft < ApplicationRecord
  DRAFT_TYPES = %w[
    birthday
    apology
    thank_you
    check_in
    congratulations
    condolence
    professional_follow_up
    invitation
    boundary_setting
  ].freeze
  LEGACY_FORMALITY_TONES = %w[casual formal].freeze
  TONES = %w[
    warm
    funny
    romantic
    professional
    concise
    emotional
    apologetic
    encouraging
  ].freeze
  RESPONSE_LENGTHS = %w[short medium long].freeze
  FORMALITIES = %w[casual balanced formal].freeze
  MAX_SITUATION_LENGTH = 4_000

  belongs_to :user
  belongs_to :relationship_profile
  has_many :draft_revisions, -> { order(position: :desc) }, dependent: :destroy, inverse_of: :message_draft

  normalizes :situation, with: -> { _1.to_s.strip }

  validates :draft_type, inclusion: { in: DRAFT_TYPES }
  validates :tone, inclusion: { in: TONES + LEGACY_FORMALITY_TONES }
  validates :response_length, inclusion: { in: RESPONSE_LENGTHS }
  validates :formality, inclusion: { in: FORMALITIES }
  validates :situation, length: { maximum: MAX_SITUATION_LENGTH }
  validates :relationship_profile_id, uniqueness: true
  validate :relationship_profile_belongs_to_user

  before_destroy :cancel_in_flight_generations, unless: :destroyed_by_association

  def current_revision
    draft_revisions.first
  end

  def effective_tone
    LEGACY_FORMALITY_TONES.include?(tone) ? "warm" : tone
  end

  def effective_formality
    LEGACY_FORMALITY_TONES.include?(tone) ? tone : formality
  end

  def append_revision!(content:, origin:, context_categories: [])
    with_lock do
      draft_revisions.create!(
        position: next_revision_position,
        content:,
        origin:,
        context_categories:
      )
    end
  end

  def save_edit!(content:, draft_type:, tone:, **response_settings)
    with_active_profile_lock do
      with_lock do
        update!(draft_type:, tone:, **response_settings)
        revision = draft_revisions.create!(
          position: next_revision_position,
          content:,
          origin: "edited",
          context_categories: current_revision&.context_categories || []
        )
        advance_generation_fence!
        revision
      end
    end
  end

  def restore_revision!(revision)
    raise ActiveRecord::RecordNotFound unless revision.message_draft_id == id

    with_active_profile_lock do
      restored_revision = append_revision!(
        content: revision.content,
        origin: "restored",
        context_categories: revision.context_categories
      )
      advance_generation_fence!
      restored_revision
    end
  end

  private

  def next_revision_position
    draft_revisions.reorder(nil).maximum(:position).to_i + 1
  end

  def cancel_in_flight_generations
    advance_generation_fence!
  end

  def advance_generation_fence!
    relationship_profile.cancel_in_flight_message_draft_generations!
  end

  def relationship_profile_belongs_to_user
    return if relationship_profile.blank? || user.blank?
    return if relationship_profile.user_id == user_id

    errors.add(:relationship_profile, :owner_mismatch)
  end

  def with_active_profile_lock
    relationship_profile.with_lock do
      raise ActiveRecord::RecordNotFound if relationship_profile.discarded?

      yield
    end
  end
end
