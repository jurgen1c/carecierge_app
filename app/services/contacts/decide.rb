module Contacts
  class Decide
    CONTACT_KINDS = { "email" => "email", "phone" => "personal_phone" }.freeze
    def self.call(**options) = new(**options).call

    def initialize(contact:, actor:, choice:, expected_version:, profile_id: nil, allow_duplicate: false)
      @contact, @actor, @choice = contact, actor, choice.to_s
      @expected_version, @profile_id, @allow_duplicate = expected_version, profile_id, allow_duplicate
    end

    def call
      raise ActiveRecord::RecordNotFound unless contact.user.id == actor.id
      actor.with_lock("FOR NO KEY UPDATE") do
        contact.contacts_connection.lock!
        contact.lock!
        raise Error.new(code: "stale") unless contact.lock_version == Integer(expected_version, exception: false)
        raise Error.new(code: "disconnected") unless contact.contacts_connection.status == "connected" || %w[undo skip].include?(choice)
        profile = contact.relationship_profile
        profile&.lock!
        Permission.check!(user: actor, profile:) unless %w[undo skip link].include?(choice)
        return contact if choice == contact.decision && (choice == "skip" || profile && %w[create link].include?(choice))
        case choice
        when "create" then create_profile!
        when "link" then link_profile!
        when "skip" then skip!
        when "update"
          return contact unless update_profile!
        when "undo" then undo!
        else raise Error.new(code: "invalid_choice")
        end
        contact.save!
        AuditEvent.record!(user: actor, actor:, action: "contacts.decision.#{choice}", target: actor, metadata: { count: 1, result: "success" })
      end
      contact
    end

    private

    attr_reader :contact, :actor, :choice, :expected_version, :profile_id, :allow_duplicate

    def ensure_unlinked!
      raise Error.new(code: "already_linked") if contact.relationship_profile_id.present?
    end

    def create_profile!
      ensure_unlinked!
      if !allow_duplicate && Matches.call(contact:).exists?
        raise Error.new(code: "duplicate")
      end
      raise Error.new(code: "missing_name") if contact.data["first_name"].blank?
      profile = actor.relationship_profiles.build(type: "RelationshipProfiles::Other", first_name: contact.data["first_name"])
      apply!(profile, contact.data)
      add_source!(profile)
      contact.assign_attributes(relationship_profile: profile, decision: "create", applied_data: snapshot(profile), previous_data: nil)
    end

    def link_profile!
      ensure_unlinked!
      profile = actor.relationship_profiles.kept.lock.find(profile_id)
      Permission.check!(user: actor, profile:)
      add_source!(profile)
      contact.assign_attributes(relationship_profile: profile, decision: "link", applied_data: snapshot(profile), previous_data: nil)
    end

    def skip!
      ensure_unlinked!
      contact.decision = "skip"
    end

    def update_profile!
      raise Error.new(code: "missing_name") if contact.data["first_name"].blank?
      profile = contact.relationship_profile || raise(Error.new(code: "missing_profile"))
      raise Error.new(code: "archived") if profile.discarded?
      raise Error.new(code: "conflict") unless snapshot(profile) == contact.applied_data
      reviewed_values = %w[first_name last_name birthday email phone].to_h { |field| [ field, contact.data[field].presence ] }
      return false if snapshot(profile).except("contact_methods") == reviewed_values
      prior_decision = contact.decision == "update" ? contact.previous_data.fetch("decision") : contact.decision
      contact.previous_data = { "profile" => snapshot(profile), "decision" => prior_decision }
      apply!(profile, contact.data)
      contact.assign_attributes(decision: "update", applied_data: snapshot(profile))
      true
    end

    def undo!
      profile = contact.relationship_profile
      if contact.decision == "update" && profile
        raise Error.new(code: "conflict") unless snapshot(profile) == contact.applied_data
        apply!(profile, contact.previous_data.fetch("profile"))
        contact.assign_attributes(decision: contact.previous_data.fetch("decision"), applied_data: snapshot(profile), previous_data: nil)
      else
        remove_source!(profile) if profile
        profile.archive! if contact.decision == "create" && profile && profile.kept?
        contact.assign_attributes(relationship_profile: nil, decision: "pending", applied_data: nil, previous_data: nil)
      end
    end

    def add_source!(profile)
      sources = Array(profile.profile_attributes["contacts_sources"])
      sources << { "provider" => "google_contacts", "imported_contact_id" => contact.id, "imported_at" => Time.current.iso8601 }
      profile.update!(profile_attributes: profile.profile_attributes.merge("contacts_sources" => sources))
    end

    def remove_source!(profile)
      sources = Array(profile.profile_attributes["contacts_sources"]).reject { |source| source["imported_contact_id"] == contact.id }
      profile.update!(profile_attributes: profile.profile_attributes.merge("contacts_sources" => sources))
    end

    def snapshot(profile)
      methods = profile.contact_methods.where(kind: CONTACT_KINDS.values).index_by(&:kind)
      { "first_name" => profile.first_name, "last_name" => profile.last_name, "birthday" => profile.birthday&.iso8601,
        "email" => methods["email"]&.value, "phone" => methods["personal_phone"]&.value,
        "contact_methods" => methods.transform_values { |method| method.attributes.slice("id", "label", "preferred") } }
    end

    def apply!(profile, data)
      profile.update!(first_name: data["first_name"], last_name: data["last_name"], birthday: data["birthday"])
      CONTACT_KINDS.each do |field, kind|
        method = profile.contact_methods.find_by(kind:)
        if data[field].present?
          metadata = data.fetch("contact_methods", {}).fetch(kind, {})
          attributes = metadata.except("id").merge("value" => data[field])
          if method
            method.update!(attributes)
          else
            profile.contact_methods.create!(attributes.merge("kind" => kind).merge(metadata.slice("id")))
          end
        else
          method&.destroy!
        end
      end
      profile.contact_methods.reset
    end
  end
end
