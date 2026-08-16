module BriefingSourceLock
  extend ActiveSupport::Concern

  included do
    before_save :lock_relationship_profile_for_briefing
    before_destroy :lock_relationship_profile_for_briefing
  end

  private

  def lock_relationship_profile_for_briefing
    return if relationship_profile_id.blank?

    RelationshipProfile.where(id: relationship_profile_id).lock.pick(:id)
  end
end
