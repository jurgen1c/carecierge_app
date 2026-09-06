require "digest"
require_relative "private_journeys"
require_relative "shared_journeys"

module DevelopmentSeeds
  class World
    class UnsafeEnvironment < StandardError; end
    class OwnershipConflict < StandardError; end

    PREFIX = "ca105000-"
    PASSWORD = "Synthetic-only-105!"
    PERSONAS = %w[new_en new_es owner_en owner_es admin vendor].freeze
    MODELS = %w[SharedItem FamilyMembership SharedRelationshipSpace ExtractedMemory PrivacyVaultItem
      ConversationRecap MemoryRecord Reminder DigestDelivery Gift EventPlan VendorAccount
      ContactsConnection MessagingConnection RelationshipProfile NotificationPreference User].freeze

    attr_reader :users, :date

    def initialize(reference_date: "2026-09-06")
      @date = Date.iso8601(reference_date)
      @users = {}
    end

    def seed!
      guard!
      User.transaction do
        # Serialize concurrent seed/reset invocations in this database.
        User.connection.execute("SELECT pg_advisory_xact_lock(105, 105)")
        PERSONAS.each { |persona| create_persona(persona) }
        PrivateJourneys.new(self).build
        SharedJourneys.new(self).build
      end
      users
    end

    def reset!
      guard!
      User.transaction do
        User.connection.execute("SELECT pg_advisory_xact_lock(105, 105)")
        records = MODELS.flat_map { |name| owned(name.constantize).to_a }
        records.each { |record| verify_dependents!(record) }
        records.each { |record| record.reload.destroy! if record.class.exists?(record.id) }
      end
    end

    def put(model, key, **attributes)
      guard!
      record = model.find_or_initialize_by(id: uuid(key))
      if record.persisted?
        attributes.each do |attribute, value|
          next unless value.is_a?(ApplicationRecord)
          raise OwnershipConflict, "Seed record ownership changed" if record.public_send(attribute)&.id != value.id
        end
      end
      record.assign_attributes(attributes)
      record.save! if record.new_record? || record.changed?
      record
    end

    def at(days = 0)
      (date + days).in_time_zone.change(hour: 12)
    end

    def uuid(key)
      hex = Digest::SHA256.hexdigest("carecierge-development-105/#{key}")
      "#{PREFIX}#{hex[0, 4]}-5105-a105-#{hex[4, 12]}"
    end

    private

    def guard!
      raise UnsafeEnvironment, "Development scenarios require RAILS_ENV=development" unless Rails.env.development?
    end

    def owned(model)
      model.where("CAST(#{model.quoted_table_name}.id AS text) LIKE ?", "#{PREFIX}%")
    end

    def verify_dependents!(record)
      record.class.reflect_on_all_associations.each do |association|
        next unless association.options[:dependent] || association.macro == :belongs_to
        related = record.public_send(association.name)
        Array(related).each do |child|
          next if child.id.to_s.start_with?(PREFIX) && MODELS.include?(child.class.base_class.name)
          raise OwnershipConflict, "Reset refused: #{record.class} has non-seed #{association.name} records"
        end
      end
    end

    def create_persona(persona)
      email = "#{persona}@carecierge.example"
      reserved = User.find_by(id: uuid("user/#{persona}"))
      raise OwnershipConflict, "Synthetic account email changed" if reserved && reserved.email != email
      existing = User.find_by(email:)
      if existing && existing.id != uuid("user/#{persona}")
        raise OwnershipConflict, "Reserved synthetic email already belongs to another account"
      end
      attributes = { email:, confirmed_at: at(-30), admin: persona == "admin",
        onboarding_completed_at: persona.start_with?("new_") ? nil : at(-20) }
      attributes[:password] = PASSWORD unless User.exists?(uuid("user/#{persona}"))
      user = put(User, "user/#{persona}", **attributes)
      users[persona] = user
      put(NotificationPreference, "preferences/#{persona}", user:, email_enabled: false,
        in_app_enabled: true, push_enabled: false, sms_enabled: false,
        time_zone: "America/Costa_Rica", time_zone_configured: true,
        digest_mode: persona.start_with?("owner_") ? "daily" : "off", digest_channel: "in_app")
    end
  end
end
