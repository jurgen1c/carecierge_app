class AllowMessagingPermission < ActiveRecord::Migration[8.1]
  CAPABILITIES = %w[draft_messages send_reminders access_contacts access_calendar suggest_gifts contact_vendors send_invitations make_reservations make_purchases pay_deposits analyze_uploaded_social_content].freeze

  def up
    replace_capabilities(CAPABILITIES + [ 'access_messages' ])
    remove_check_constraint :automation_permissions, name: 'automation_permissions_high_impact_mode_check'
    add_check_constraint :automation_permissions, "capability NOT IN ('make_purchases', 'pay_deposits', 'access_messages') OR mode <> 'allow_automatically'", name: 'automation_permissions_high_impact_mode_check'
  end

  def down
    # Preserve append-only permission history rather than silently delete it on rollback.
    if select_value("SELECT 1 FROM automation_permissions WHERE capability = 'access_messages' LIMIT 1") ||
        select_value("SELECT 1 FROM automation_permission_changes WHERE capability = 'access_messages' LIMIT 1")
      raise ActiveRecord::IrreversibleMigration, 'Messaging permission evidence must be retained'
    end
    replace_capabilities(CAPABILITIES)
    remove_check_constraint :automation_permissions, name: 'automation_permissions_high_impact_mode_check'
    add_check_constraint :automation_permissions, "capability NOT IN ('make_purchases', 'pay_deposits') OR mode <> 'allow_automatically'", name: 'automation_permissions_high_impact_mode_check'
  end

  private

  def replace_capabilities(values)
    [ :automation_permissions, :automation_permission_changes ].each do |table|
      name = "#{table}_capability_check"
      remove_check_constraint table, name: name
      add_check_constraint table, "capability IN (#{values.map { |value| connection.quote(value) }.join(', ')})", name: name
    end
  end
end
