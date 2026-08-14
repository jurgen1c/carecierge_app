class SocialContextScreenshotPolicy < ApplicationPolicy
  def show?
    user.present? && record.uploaded_by_user_id == user.id
  end
end
