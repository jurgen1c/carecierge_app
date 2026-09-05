class ContactsConnectionPolicy < ApplicationPolicy
  def show? = user.present?
  def new? = user.present?
  def callback? = user.present?
  def refresh? = user.present?
  def decide? = user.present?
  def destroy? = user.present?
end
