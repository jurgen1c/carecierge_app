class CreateAutomationPermissions < ActiveRecord::Migration[8.1]
  CAPABILITIES = %w[
    draft_messages
    send_reminders
    access_contacts
    access_calendar
    suggest_gifts
    contact_vendors
    send_invitations
    make_reservations
    make_purchases
    pay_deposits
    analyze_uploaded_social_content
  ].freeze
  MODES = %w[disabled ask_every_time allow_automatically].freeze
  ACTIONS = %w[created updated removed].freeze
  HIGH_IMPACT_CAPABILITIES = %w[make_purchases pay_deposits].freeze

  def change
    create_table :automation_permissions, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :relationship_profile, foreign_key: true, type: :uuid
      t.string :capability, null: false
      t.string :mode, null: false

      t.timestamps
    end

    add_index :automation_permissions,
              %i[user_id capability],
              unique: true,
              where: "relationship_profile_id IS NULL",
              name: "idx_automation_permissions_account_defaults"
    add_index :automation_permissions,
              %i[user_id relationship_profile_id capability],
              unique: true,
              where: "relationship_profile_id IS NOT NULL",
              name: "idx_automation_permissions_relationship_overrides"
    add_check_constraint :automation_permissions,
                         "capability IN (#{quoted_list(CAPABILITIES)})",
                         name: "automation_permissions_capability_check"
    add_check_constraint :automation_permissions,
                         "mode IN (#{quoted_list(MODES)})",
                         name: "automation_permissions_mode_check"
    add_check_constraint :automation_permissions,
                         "capability NOT IN (#{quoted_list(HIGH_IMPACT_CAPABILITIES)}) OR mode <> 'allow_automatically'",
                         name: "automation_permissions_high_impact_mode_check"

    create_table :automation_permission_changes, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :actor, null: false, foreign_key: { to_table: :users }, type: :uuid
      # Keep the UUID after profile deletion so append-only audit scope remains intact.
      t.references :relationship_profile, type: :uuid
      t.string :capability, null: false
      t.string :action, null: false
      t.string :previous_mode
      t.string :new_mode

      t.timestamps
    end

    add_index :automation_permission_changes, %i[user_id created_at]
    add_index :automation_permission_changes, %i[relationship_profile_id created_at],
              name: "idx_automation_permission_changes_relationship_time"
    add_check_constraint :automation_permission_changes,
                         "capability IN (#{quoted_list(CAPABILITIES)})",
                         name: "automation_permission_changes_capability_check"
    add_check_constraint :automation_permission_changes,
                         "action IN (#{quoted_list(ACTIONS)})",
                         name: "automation_permission_changes_action_check"
    add_check_constraint :automation_permission_changes,
                         "previous_mode IS NULL OR previous_mode IN (#{quoted_list(MODES)})",
                         name: "automation_permission_changes_previous_mode_check"
    add_check_constraint :automation_permission_changes,
                         "new_mode IS NULL OR new_mode IN (#{quoted_list(MODES)})",
                         name: "automation_permission_changes_new_mode_check"
    add_check_constraint :automation_permission_changes,
                         "(action = 'removed' AND new_mode IS NULL) OR (action IN ('created', 'updated') AND new_mode IS NOT NULL)",
                         name: "automation_permission_changes_action_mode_check"
    add_check_constraint :automation_permission_changes,
                         "actor_id = user_id",
                         name: "automation_permission_changes_actor_owner_check"
  end

  private

  def quoted_list(values)
    values.map { |value| connection.quote(value) }.join(", ")
  end
end
