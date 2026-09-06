module DevelopmentSeeds
  class PrivateJourneys
    def initialize(world)
      @world = world
    end

    def build
      %w[owner_en owner_es].each { |persona| build_owner(persona) }
      put(VendorAccount, "vendor/account", user: @world.users.fetch("vendor"),
        business_name: "Synthetic Orchid Studio", categories: [ "florist" ],
        service_area: "Synthetic town", offerings: "Demonstration bouquets",
        contact_channels: "vendor@carecierge.example", source_url: "https://vendor.example",
        provenance: "Synthetic development fixture", status: "submitted")
    end

    private

    delegate :put, :at, to: :@world

    def build_owner(persona)
      user = @world.users.fetch(persona)
      profile = put(RelationshipProfiles::Friend, "#{persona}/friend", user:,
        first_name: "Alex", last_name: "Synthetic #{persona}")
      put(RelationshipProfiles::Colleague, "#{persona}/work", user:, first_name: "Sam",
        last_name: "Synthetic colleague #{persona}", relationship_mode: "professional",
        professional_context: { "organization" => "Example Studio", "boundaries" => "Work topics only; no gifts", "gifts_allowed" => "0" })
      build_memories(persona, profile)
      build_planning(persona, user, profile)
      put(ContactsConnection, "#{persona}/contacts", user:, status: "authorization_required")
      put(MessagingConnection, "#{persona}/messaging", user:, status: "authorization_required")
    end

    def build_memories(key, profile)
      put(MemoryRecord, "#{key}/memory", relationship_profile: profile,
        title: "Jasmine tea", body: "Synthetic Alex enjoys jasmine tea.")
      protected = put(MemoryRecord, "#{key}/protected", relationship_profile: profile,
        title: PrivacyVaultItem::REDACTED_TEXT, body: PrivacyVaultItem::REDACTED_TEXT)
      put(PrivacyVaultItem, "#{key}/vault", relationship_profile: profile, protectable: protected,
        protected_at: at(-7), payload: { "title" => "Synthetic private memory", "body" => "Fictional private context for vault walkthrough." })
      recap = put(ConversationRecap, "#{key}/recap", relationship_profile: profile,
        title: "Synthetic tea conversation", body: "Alex said: I enjoy jasmine tea.",
        occurred_at: at(-2), extraction_status: "ready_for_review", extraction_approved_at: at(-2), extraction_completed_at: at(-2))
      put(ExtractedMemory, "#{key}/proposal", relationship_profile: profile, conversation_recap: recap,
        title: "Jasmine tea preference", body: "Alex enjoys jasmine tea.", category: "preference",
        confidence: "medium", source_excerpt: "I enjoy jasmine tea.")
      put(ConversationRecap, "#{key}/failure", relationship_profile: profile,
        title: "Synthetic failed extraction", body: "Fictional provider failure example.",
        occurred_at: at(-1), extraction_status: "failed", extraction_error_code: "provider_unavailable")
    end

    def build_planning(key, user, profile)
      put(Reminder, "#{key}/reminder", user:, relationship_profile: profile,
        title: "Synthetic tea check-in", scheduled_at: at(1), recurrence_anchor_at: at(1), next_delivery_at: at(1), time_zone: "America/Costa_Rica")
      put(DigestDelivery, "#{key}/digest", user:, mode: "daily", channel: "in_app",
        scheduled_for: at(-1), status: "dispatched", dispatched_at: at(-1))
      put(EventPlan, "#{key}/plan", user:, relationship_profile: profile,
        title: "Synthetic birthday tea", occasion_type: "birthday", starts_on: @world.date + 7, source_context: [])
      put(Gift, "#{key}/gift", relationship_profile: profile, name: "Synthetic ceramic mug", status: "idea")
    end
  end
end
