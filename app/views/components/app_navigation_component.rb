class AppNavigationComponent < ApplicationViewComponent
  option :user
  option :current_controller

  PEOPLE_CONTROLLERS = %w[relationship_profiles important_dates interactions contact_cadences
    commitments desires gifts gift_boxes gift_purchase_plans external_provider_actions memory_records mood_notes
    timeline_entries conversation_recaps extracted_memories relationship_briefings message_drafts social_context_notes
    privacy_vaults privacy_vault_items suggestions gift_recommendations professional_relationships].freeze

  style :link do
    base { %w[app-nav-link] }
    variants do
      active do
        yes { %w[app-nav-link-current] }
        no { [] }
      end
    end
  end

  def groups
    everyday = [
      entry(:today, :today, dashboard_path, %w[dashboard]),
      entry(:people, :people, relationship_profiles_path, PEOPLE_CONTROLLERS),
      entry(:reminders, :reminders, reminders_path, %w[reminders]),
      entry(:plans, :plans, event_plans_path, %w[event_plans plan_tasks backup_plans personal_touch_checklists personal_touch_items bookings vendor_quotes]),
      entry(:shared, :shared, shared_relationship_spaces_path, %w[shared_relationship_spaces shared_items family_memberships])
    ]
    tools = [
      entry(:reviews, :reviews, approvals_path, %w[approval_requests]),
      entry(:search, :search, relationship_search_path, %w[relationship_searches]),
      entry(:marketplace, :explore, marketplace_listings_path, %w[marketplace_listings]),
      entry(:vendors, :explore, vendors_path, %w[vendors vendor_shortlists vendor_options])
    ]
    account = [
      entry(:notifications, :settings, edit_notification_preference_path, %w[notification_preferences]),
      entry(:permissions, :privacy, edit_automation_permissions_path, %w[automation_permissions automation_permission_overrides]),
      entry(:calendar, :plans, calendar_connection_path, %w[calendar_connections]),
      entry(:contacts, :people, contacts_connection_path, %w[contacts_connections]),
      entry(:messages, :activity, messaging_connection_path, %w[messaging_connections]),
      entry(:activity, :activity, audit_events_path, %w[audit_events]),
      entry(:privacy, :privacy, data_control_path, %w[data_controls data_exports data_deletions vault_mfas]),
      entry(:business, :explore, vendor_account_path, %w[vendor_accounts])
    ]
    result = { everyday: everyday, tools: tools, account: account }
    if user.admin?
      result[:admin] = [
        entry(:admin, :settings, admin_root_path, %w[admin/dashboard]),
        entry(:admin_activity, :activity, admin_audit_events_path, %w[admin/audit_events]),
        entry(:admin_vendors, :explore, admin_vendor_accounts_path, %w[admin/vendor_accounts]),
        entry(:admin_flags, :settings, admin_feature_flags_path, %w[admin/feature_flags])
      ]
    end
    result
  end

  private

  def entry(key, icon, path, controllers)
    { key:, icon:, path:, active: controllers.include?(current_controller) }
  end
end
