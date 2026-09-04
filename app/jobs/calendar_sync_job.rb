class CalendarSyncJob < ApplicationJob
  queue_as :background

  retry_on CalendarProviders::TransientError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveJob::DeserializationError

  def perform(connection, owner_requested: false)
    CalendarSyncs::Run.call(connection:, owner_requested:)
  end
end
