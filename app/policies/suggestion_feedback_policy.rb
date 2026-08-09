class SuggestionFeedbackPolicy < ApplicationPolicy
  def feedback?
    owner?
  end

  def dismiss?
    owner?
  end

  def act?
    owner?
  end

  private

  def owner?
    record.user_id == user.id && record.relationship_profile.user_id == user.id
  end
end
