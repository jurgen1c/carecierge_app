class FeedItemStatePolicy < ApplicationPolicy
  def update?
    record.user_id == user.id
  end
end
