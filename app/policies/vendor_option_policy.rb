class VendorOptionPolicy < ApplicationPolicy
  def create? = owner? && record.vendor_shortlist.mutable?
  def update? = owner? && record.vendor_shortlist.mutable?
  def destroy? = owner?

  private

  def owner? = user.present? && record.vendor_shortlist.user_id == user.id
end
