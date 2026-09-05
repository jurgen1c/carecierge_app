class MessagingConnectionPolicy < ApplicationPolicy
  def show? = user.present?
  def connect? = user.present?
  def callback? = user.present?
  def search? = user.present?
  def import? = user.present?
  def draft? = user.present?
  def edit_draft? = user.present?
  def delete_context? = user.present?
  def destroy? = user.present?
end
