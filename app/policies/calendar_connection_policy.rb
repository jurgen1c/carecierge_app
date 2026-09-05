class CalendarConnectionPolicy < ApplicationPolicy
  def show? = class_record? ? user.present? : owner?
  def new? = user.present?
  def create? = user.present?
  def callback? = user.present?
  def update? = owner?
  def sync? = owner?
  def destroy? = owner?

  private

  def class_record? = record == CalendarConnection
  def owner? = user.present? && record.is_a?(CalendarConnection) && record.user_id == user.id
end
