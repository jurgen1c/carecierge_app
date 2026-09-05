module AdminDashboard
  # Cross-account aggregates only. Call after the admin policy has authorized access.
  class Query
    def accounts
      {
        accounts_total: User.count,
        accounts_confirmed: User.where.not(confirmed_at: nil).count,
        accounts_locked: User.where.not(locked_at: nil).count,
        features_enabled: FeatureFlag.active.where(enabled: true).count,
        features_active: FeatureFlag.active.count,
        listings_published: MarketplaceListing.published.count,
        listings_unpublished: MarketplaceListing.where(published: false).count
      }
    end

    def approvals
      waiting = ApprovalRequest.pending_review.reorder(nil)
      {
        approval_waiting: waiting.count,
        approval_deferred: ApprovalRequest.where(status: "deferred").where("deferred_until > ?", Time.current).count,
        approval_sensitive: waiting.where(risk_level: %w[high sensitive]).count,
        approval_oldest: waiting.minimum(:created_at)
      }
    end

    def integrations
      {
        calendar_total: CalendarConnection.count,
        calendar_failed: CalendarConnection.where(sync_status: "failed").count,
        calendar_action_required: CalendarConnection.where(sync_status: "action_required").count,
        calendar_stalled: CalendarConnection.where(sync_status: "syncing", sync_lease_expires_at: ..Time.current).count,
        calendar_cleanup: CalendarCredentialRevocation.count,
        contacts_total: ContactsConnection.count,
        contacts_attention: ContactsConnection.where(status: %w[cleanup_required authorization_required]).count,
        messaging_total: MessagingConnection.count,
        messaging_attention: MessagingConnection.where(status: %w[cleanup_required authorization_required]).count
      }
    end

    def trust
      {
        vault_unlock_failures: AuditEvent.where(action: "privacy_vault.unlock_failed", occurred_at: 24.hours.ago..Time.current).count,
        feedback_not_for_me: SuggestionFeedback.where(feedback: "not_for_me").count
      }
    end
  end
end
