class DataControlPolicy < ApplicationPolicy
  def show?
    user.present?
  end

  def create?
    show?
  end
end
