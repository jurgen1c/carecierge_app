class DispatchCalendarSyncsJob < ApplicationJob
  queue_as :background

  def perform
    CalendarConnection.eligible_for_sync.find_each do |connection|
      CalendarSyncJob.perform_later(connection)
    end
  end
end
