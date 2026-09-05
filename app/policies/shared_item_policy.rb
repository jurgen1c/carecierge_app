class SharedItemPolicy < ApplicationPolicy
  def create? = record.shared_relationship_space.active? && record.shared_relationship_space.participant?(user)
  def show? = create?
  def update? = record.editable_by?(user)
  def destroy? = create? && record.creator_id == user.id
end
