class VaultMfaCredentialPolicy < ApplicationPolicy
  def show?
    user.present? && record.user_id == user.id
  end

  alias_method :update?, :show?
end
