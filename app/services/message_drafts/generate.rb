module MessageDrafts
  class Generate
    def self.call(
      actor:,
      relationship_profile:,
      draft_type:,
      tone:,
      situation: "",
      response_length: "medium",
      formality: "balanced",
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
        situation:,
        response_length:,
        formality:,
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
      situation:,
      response_length:,
      formality:,
      include_private_notes:,
      include_vault_context:,
      vault_lease:,
      locale:,
      generator:
    )
      @actor = actor
      @relationship_profile = relationship_profile
      @draft_type = draft_type
      @tone, @formality = normalized_tone_and_formality(tone, formality)
      @situation = situation.to_s.strip
      @response_length = response_length.presence || "medium"
      @include_private_notes = include_private_notes
      @include_vault_context = include_vault_context
      @vault_lease = vault_lease
      @locale = locale
      @generator = generator
    end

    def call
      generation_version, context, draft_id = prepare_generation!
      record_sensitive_access(context.categories)
      content = generator.generate(
        draft_type:,
        tone:,
        situation:,
        response_length:,
        formality:,
        context: context.text,
        locale:
      )

      relationship_profile.with_lock do
        raise ActiveRecord::RecordNotFound if relationship_profile.discarded?
        reject_stale_generation!(generation_version:, draft_id:)

        draft = MessageDraft.find_by!(id: draft_id, relationship_profile:)
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

    def normalized_tone_and_formality(tone, formality)
      return [ "warm", tone ] if MessageDraft::LEGACY_FORMALITY_TONES.include?(tone)

      [ tone, formality.presence || "balanced" ]
    end

    attr_reader :actor,
      :relationship_profile,
      :draft_type,
      :tone,
      :situation,
      :response_length,
      :formality,
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

          draft = persist_draft_settings!
          relationship_profile.increment!(:message_draft_generation_version)

          [ relationship_profile.message_draft_generation_version, context, draft.id ]
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
      draft.assign_attributes(
        user: actor,
        relationship_profile:,
        draft_type:,
        tone:,
        situation:,
        response_length:,
        formality:
      )
      raise ActiveRecord::RecordInvalid, draft unless draft.valid?
    end

    def persist_draft_settings!
      draft = MessageDraft.find_or_initialize_by(relationship_profile:)
      draft.assign_attributes(
        user: actor,
        draft_type:,
        tone:,
        situation:,
        response_length:,
        formality:
      )
      draft.save!
      draft
    end

    def reject_stale_generation!(generation_version:, draft_id:)
      return if relationship_profile.message_draft_generation_version == generation_version
      raise ActiveRecord::RecordNotFound unless MessageDraft.exists?(id: draft_id, relationship_profile_id: relationship_profile.id)

      raise GenerationSupersededError, "A newer message drafting request superseded this generation"
    end
  end
end
