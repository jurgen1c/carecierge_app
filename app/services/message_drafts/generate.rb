module MessageDrafts
  class Generate
    def self.call(
      actor:,
      relationship_profile:,
      draft_type:,
      tone:,
      include_private_notes: false,
      include_vault_context: false,
      vault_lease: nil,
      locale: I18n.locale,
      generator: OpenAiGenerator.new
    )
      new(
        actor:,
        relationship_profile:,
        draft_type:,
        tone:,
        include_private_notes:,
        include_vault_context:,
        vault_lease:,
        locale:,
        generator:
      ).call
    end

    def initialize(
      actor:,
      relationship_profile:,
      draft_type:,
      tone:,
      include_private_notes:,
      include_vault_context:,
      vault_lease:,
      locale:,
      generator:
    )
      @actor = actor
      @relationship_profile = relationship_profile
      @draft_type = draft_type
      @tone = tone
      @include_private_notes = include_private_notes
      @include_vault_context = include_vault_context
      @vault_lease = vault_lease
      @locale = locale
      @generator = generator
    end

    def call
      generation_version, context = prepare_generation!
      record_sensitive_access(context.categories)
      content = generator.generate(draft_type:, tone:, context: context.text, locale:)

      relationship_profile.with_lock do
        raise ActiveRecord::RecordNotFound if relationship_profile.discarded?
        raise ActiveRecord::RecordNotFound unless relationship_profile.message_draft_generation_version == generation_version

        draft = MessageDraft.find_or_initialize_by(relationship_profile:)
        draft.assign_attributes(user: actor, draft_type:, tone:)
        draft.save!
        revision = draft.append_revision!(
          content:,
          origin: "generated",
          context_categories: context.categories
        )
        AuditEvent.record!(
          user: actor,
          actor:,
          action: "message.drafted",
          target: relationship_profile,
          metadata: { result: "generated" }
        )
        revision
      end
    end

    private

    attr_reader :actor,
      :relationship_profile,
      :draft_type,
      :tone,
      :include_private_notes,
      :include_vault_context,
      :vault_lease,
      :locale,
      :generator

    def prepare_generation!
      actor.with_lock do
        relationship_profile.with_lock do
          raise ActiveRecord::RecordNotFound unless relationship_profile.user_id == actor.id && !relationship_profile.discarded?

          validate_draft_settings!
          validate_vault_access!
          context = ContextBuilder.new(
            relationship_profile:,
            include_private_notes:,
            include_vault_context:
          ).call

          [ relationship_profile.message_draft_generation_version, context ]
        end
      end
    end

    def validate_vault_access!
      return unless include_vault_context
      return if vault_lease&.active_for?(actor)

      raise VaultAccessError, "Privacy vault access is required"
    end

    def record_sensitive_access(categories)
      return if (categories & %w[private_notes vault]).empty?

      AuditEvent.record!(
        user: actor,
        actor:,
        action: "sensitive_record.accessed",
        target: relationship_profile,
        metadata: { result: "message_drafting" }
      )
      return unless categories.include?("vault")

      VaultAccessEvent.record_safely(
        event_type: "viewed",
        user: actor,
        relationship_profile:
      )
    end

    def validate_draft_settings!
      draft = MessageDraft.find_by(relationship_profile:) || MessageDraft.new
      draft.assign_attributes(user: actor, relationship_profile:, draft_type:, tone:)
      raise ActiveRecord::RecordInvalid, draft unless draft.valid?
    end
  end
end
