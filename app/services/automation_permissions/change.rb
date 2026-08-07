module AutomationPermissions
  class Change
    def self.call(user:, actor:, capability:, mode:, relationship_profile: nil)
      new(user:, actor:).call(capability:, mode:, relationship_profile:)
    end

    def self.remove!(permission:, actor:)
      new(user: permission.user, actor:).remove!(permission:)
    end

    def self.call_defaults(user:, actor:, modes:)
      new(user:, actor:).call_defaults(modes:)
    end

    def initialize(user:, actor:)
      @user = user
      @actor = actor
    end

    def call(capability:, mode:, relationship_profile: nil)
      definition = AutomationCapability.fetch(capability)
      owned_relationship = owned_relationship_profile(relationship_profile)
      validate_actor!

      user.with_lock do
        apply_change(definition:, mode:, owned_relationship:)
      end
    end

    def call_defaults(modes:)
      changes = modes.map { |capability, mode| [ AutomationCapability.fetch(capability), mode ] }
      validate_actor!

      user.with_lock do
        changes.each do |definition, mode|
          apply_change(definition:, mode:, owned_relationship: nil)
        end
      end
    end

    def remove!(permission:)
      validate_actor!
      raise ArgumentError, "only relationship overrides can be removed" unless permission.override?
      raise ActiveRecord::RecordNotFound unless permission.user_id == user.id

      user.with_lock do
        permission.lock!
        record_change!(
          permission:,
          action: "removed",
          previous_mode: permission.mode,
          new_mode: nil
        )
        permission.destroy!
      end
    end

    private

    attr_reader :actor, :user

    def validate_actor!
      return if actor&.id == user.id

      raise ArgumentError, "actor must be the permission owner"
    end

    def owned_relationship_profile(relationship_profile)
      return if relationship_profile.blank?

      user.relationship_profiles.kept.find(relationship_profile.id)
    end

    def apply_change(definition:, mode:, owned_relationship:)
      permission = user.automation_permissions
        .lock
        .find_or_initialize_by(capability: definition.key, relationship_profile: owned_relationship)
      previous_mode = previous_mode_for(permission:, definition:, owned_relationship:)

      return permission if previous_mode == mode.to_s && (permission.persisted? || owned_relationship.nil?)

      permission.mode = mode
      permission.save!
      record_change!(
        permission:,
        action: permission.previously_new_record? ? "created" : "updated",
        previous_mode:,
        new_mode: permission.mode
      )
      permission
    end

    def previous_mode_for(permission:, definition:, owned_relationship:)
      return permission.mode if permission.persisted?
      return "disabled" unless owned_relationship

      user.automation_permissions.account_defaults.find_by(capability: definition.key)&.mode || "disabled"
    end

    def record_change!(permission:, action:, previous_mode:, new_mode:)
      AutomationPermissionChange.create!(
        user:,
        actor:,
        relationship_profile: permission.relationship_profile,
        capability: permission.capability,
        action:,
        previous_mode:,
        new_mode:
      )
    end
  end
end
