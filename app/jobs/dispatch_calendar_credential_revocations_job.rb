class DispatchCalendarCredentialRevocationsJob < ApplicationJob
  queue_as :background

  def perform
    CalendarCredentialRevocation.due.find_each do |revocation|
      CalendarCredentialRevocationJob.perform_later(revocation)
    end
  end
end
