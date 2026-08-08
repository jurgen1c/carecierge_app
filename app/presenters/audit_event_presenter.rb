class AuditEventPresenter
  def initialize(event)
    @event = event
  end

  def title
    I18n.t("audit_events.actions.#{translation_key}.title")
  end

  def description
    I18n.t("audit_events.actions.#{translation_key}.description", target: target_label)
  end

  def source_label
    I18n.t("audit_events.sources.#{event.source}")
  end

  def actor_label
    return event.actor.email if event.actor

    I18n.t("audit_events.actors.#{event.actor_kind}")
  end

  def target_label(reveal_relationship_name: true)
    case event.target
    when RelationshipProfile
      reveal_relationship_name ? event.target.display_name : I18n.t("audit_events.targets.relationship_profile")
    when Reminder then I18n.t("audit_events.targets.reminder")
    when AutomationPermission then I18n.t("audit_events.targets.automation_permission")
    when PrivacyVaultItem then I18n.t("audit_events.targets.privacy_vault")
    when User then I18n.t("audit_events.targets.account")
    when nil then I18n.t("audit_events.targets.deleted_resource")
    else I18n.t("audit_events.targets.resource")
    end
  end

  def tone
    return :deletion if event.action.include?("deleted") || event.action == "data_deletion.requested"
    return :security if event.action.start_with?("privacy_vault.") || event.action.in?(%w[approval.granted permission.changed sensitive_record.accessed])

    :standard
  end

  private

  attr_reader :event

  def translation_key
    event.action.tr(".", "_")
  end
end
