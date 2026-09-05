class GiftBoxPolicy < ApplicationPolicy
  def create? = owns_profile?
  def show? = owns_profile?
  def update? = owns_profile?
  def destroy? = owns_profile?

  private

  def owns_profile?
    user.present? && record.relationship_profile.user_id == user.id && record.relationship_profile.kept?
  end
end
