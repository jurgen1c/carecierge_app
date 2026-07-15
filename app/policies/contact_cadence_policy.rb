class ContactCadencePolicy < ApplicationPolicy
  def create?
    owns_profile?
  end

  def update?
    owns_profile?
  end

  private

  def owns_profile?
    user.present? && record.relationship_profile.user_id == user.id
  end
end
