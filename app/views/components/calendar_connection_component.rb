class CalendarConnectionComponent < ApplicationViewComponent
  option :connection, optional: true
  option :provider_available
  option :credential_revocation_pending, default: proc { false }

  style :status do
    base { %w[inline-flex min-h-7 items-center rounded-full border px-3 py-1 text-xs font-semibold] }
    variants do
      status do
        connected { %w[border-primary/30 bg-surface text-primary] }
        syncing { %w[border-private-line bg-surface text-ink] }
        failed { %w[border-danger-border bg-danger-surface text-danger-ink] }
        action_required { %w[border-danger-border bg-danger-surface text-danger-ink] }
      end
    end
  end

  style :switch_track do
    base do
      %w[
        h-7 w-12 rounded-full bg-stone-300 transition peer-checked:bg-primary peer-focus-visible:outline
        peer-focus-visible:outline-2 peer-focus-visible:outline-offset-2 peer-focus-visible:outline-primary
      ]
    end
  end

  style :switch_thumb do
    base { %w[pointer-events-none absolute left-1 size-5 rounded-full bg-canvas transition peer-checked:translate-x-5] }
  end

  def connected? = connection.present?
  def status = connection.sync_status.to_sym
  def error? = connection.last_error_code.present?
  def syncing? = connection&.actively_syncing?
  def reconnect_required? = connection&.sync_status == "action_required"
  def revocation_failed? = connection&.last_error_code == "revocation_failed"
  def permission_required? = connection&.last_error_code == "calendar_permission_required"
  def sync_control? = syncing? || connection&.syncable?(owner_requested: true)

  def error_recovery_key
    connection.last_error_code == "revocation_failed" ? "revocation_recovery" : "error_recovery"
  end

  def sync_action_label
    key = error? ? "retry_sync" : "sync_now"
    t("calendar_connections.show.#{key}")
  end
end
