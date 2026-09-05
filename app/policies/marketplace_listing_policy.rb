class MarketplaceListingPolicy < ApplicationPolicy
  def index? = user.present?
  def compare? = index?
  def show? = user.present? && record.published?
  def save? = show?
  def use? = show?

  class Scope < ApplicationPolicy::Scope
    def resolve = user ? scope.published : scope.none
  end
end
