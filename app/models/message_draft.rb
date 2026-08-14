# == Schema Information
#
# Table name: message_drafts
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  draft_type              :string           not null
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
  TONES = %w[
    warm
    funny
    romantic
    professional
    concise
    emotional
    apologetic
    casual
    formal
    encouraging
  ].freeze

  belongs_to :user
  belongs_to :relationship_profile
  has_many :draft_revisions, -> { order(position: :desc) }, dependent: :destroy, inverse_of: :message_draft

  validates :draft_type, inclusion: { in: DRAFT_TYPES }
  validates :tone, inclusion: { in: TONES }
  validates :relationship_profile_id, uniqueness: true
  validate :relationship_profile_belongs_to_user

  before_destroy :cancel_in_flight_generations, unless: :destroyed_by_association

  def current_revision
    draft_revisions.first
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

  def save_edit!(content:, draft_type:, tone:)
    with_active_profile_lock do
      with_lock do
        update!(draft_type:, tone:)
        draft_revisions.create!(
          position: next_revision_position,
          content:,
          origin: "edited",
          context_categories: current_revision&.context_categories || []
        )
      end
    end
  end

  def restore_revision!(revision)
    raise ActiveRecord::RecordNotFound unless revision.message_draft_id == id

    with_active_profile_lock do
      append_revision!(
        content: revision.content,
        origin: "restored",
        context_categories: revision.context_categories
      )
    end
  end

  private

  def next_revision_position
    draft_revisions.reorder(nil).maximum(:position).to_i + 1
  end

  def cancel_in_flight_generations
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
