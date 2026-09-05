module AdminDashboard
  class QueueStatus
    def metrics
      return { queue_available: false } unless models.all?(&:table_exists?)

      {
        queue_available: true,
        jobs_failed: SolidQueue::FailedExecution.count,
        jobs_ready: SolidQueue::ReadyExecution.count,
        jobs_scheduled: SolidQueue::ScheduledExecution.count,
        jobs_blocked: SolidQueue::BlockedExecution.count,
        workers_recent: SolidQueue::Process.where(kind: "Worker", last_heartbeat_at: 5.minutes.ago..).count
      }
    rescue ActiveRecord::ActiveRecordError
      Rails.logger.warn("admin_dashboard.queue_unavailable")
      { queue_available: false }
    end

    private

    def models
      [ SolidQueue::FailedExecution, SolidQueue::ReadyExecution, SolidQueue::ScheduledExecution,
        SolidQueue::BlockedExecution, SolidQueue::Process ]
    end
  end
end
