module Concierge
  class GeneratedSources
    def self.authorization_version(profile:, turn:)
      RecordVersion.digest([ profile.id, Context.profile_snapshot(profile),
        turn.context.slice("relationship_profile_id", "private_note_ids", "vault_item_ids", "selected_versions")
          .merge("authored_private_notes" => turn.context.fetch("authored_private_notes", {}),
            "private_context_ids" => Context.private_note_provenance(turn.context)),
        profile.professional? ? ProfessionalContext::COLLECTIONS.to_h do |collection|
          [ collection, profile.work_context.selected(collection).order(:id).map { |record| [ record.id, RecordVersion.for(record) ] } ]
        end : {} ])
    end

    def self.visible?(record, turn:)
      return false unless record && turn
      profile = record.is_a?(DraftRevision) ? record.message_draft.relationship_profile : record.relationship_profile
      return false unless profile.user_id == turn.conversation.user_id && !profile.archived?
      mode = record.is_a?(DraftRevision) ? record.message_draft.relationship_mode : record.relationship_mode
      return false unless mode == profile.relationship_mode
      Context.verify!(turn:)
      sources = case record
      when RelationshipBriefing then record.sections.flat_map { |section| section.fetch("items").flat_map { |item| item.fetch("sources") } }
      when GiftRecommendation then record.source_context
      else []
      end
      return false unless OccasionSources.sources_authorized?(sources, profile_id: profile.id, turn:)
      categories = if record.is_a?(GiftRecommendation)
        [ ("private_notes" if record.include_private_notes?), ("vault" if record.include_vault_context?) ].compact
      else
        record.context_categories
      end
      return false if record.is_a?(DraftRevision) && categories.include?("professional") != profile.professional?
      draft_provenance_required = record.is_a?(DraftRevision) && categories.any?
      consent_origin_required = draft_provenance_required || (categories & %w[private_notes vault]).any? || profile.professional?

      # Existing category-wide drafts cannot establish consent to reuse their text in
      # chat. Only a chat origin with the same still-authorized selections can do so.
      candidates = ConciergeAction.joins(turn: :conversation)
        .where(concierge_conversations: { user_id: profile.user_id }).where(state: "succeeded")
        .where(name: ConciergeAction::SOURCE_ORIGIN_NAMES)
        .where("source_keys @> ARRAY[?]::text[]", ConciergeAction.generated_source_key(type: record.class.name, id: record.id))
      return !record.concierge_origin_required? && !consent_origin_required if candidates.empty?

      candidates.any? do |action|
        references = Array(action.result["records"]) + [ action.result["record"] ].compact
        next false unless references.any? { |reference| reference["record_type"] == record.class.name && reference["id"] == record.id }
        next false unless OccasionSources.sources_authorized?(action.result["generation_sources"], profile_id: profile.id, turn:)
        unless record.is_a?(DraftRevision)
          stored = action.result["generation_sources"]
          current = generation_sources(profile:, turn:, value: action.result).to_a.index_by { |source| source["id"] }
          next false unless stored.is_a?(Array) && stored.all? do |source|
            source["version"].present? && current.dig(source["id"], "version") == source["version"]
          end
        end
        origin = action.turn
        scoped_origin = Context.private_note_provenance(origin.context).any? || Array(origin.context["vault_item_ids"]).any?
        next true unless consent_origin_required || scoped_origin

        next false if draft_provenance_required && action.result["draft_context_version"] != draft_context_version(profile:, turn:)
        next false unless action.result["authorization_version"] == authorization_version(profile:, turn:)
        origin = ReadTurn.new(turn: origin, vault_lease: turn.vault_lease) if turn.is_a?(ReadTurn)
        Context.verify!(turn: origin)
        %w[relationship_profile_id private_note_ids vault_item_ids selected_versions].all? { |key| origin.context[key] == turn.context[key] } &&
          origin.context.fetch("authored_private_notes", {}) == turn.context.fetch("authored_private_notes", {})
      rescue Error, ActiveRecord::RecordNotFound
        false
      end
    rescue Error, ActiveRecord::RecordNotFound
      false
    end

    def self.mark_origin!(record)
      # Write-once authorization metadata, inside the domain creation transaction.
      # Draft content remains immutable; deleting chat must not remove this fence.
      record.class.where(id: record.id).update_all(concierge_origin_required: true)
      record.reload
    end

    def self.generation_sources(profile:, turn:, value:)
      records = Array(value["records"]) + [ value["record"] ].compact
      selected = turn.context["relationship_profile_id"] == profile.id
      private_ids = selected ? Array(turn.context["private_note_ids"]) : []
      vault_ids = selected ? Array(turn.context["vault_item_ids"]) : []
      options = { relationship_profile: profile, private_note_ids: private_ids, vault_item_ids: vault_ids, locale: :en }
      context = with_owner_context(profile:) do
        if records.any? { |record| record["record_type"] == "RelationshipBriefing" }
          ::RelationshipBriefings::ContextBuilder.new(**options, include_private_notes: private_ids.any?, include_vault_context: vault_ids.any?).call
        elsif records.any? { |record| record["record_type"] == "GiftRecommendation" }
          ::GiftRecommendations::ContextBuilder.new(**options).call
        end
      end
      context&.sources&.map { |source| { "id" => source.id, "sensitive" => source.sensitive, "version" => RecordVersion.digest(source.to_h) } }
    end

    def self.draft_context_version(profile:, turn:)
      selected = turn.context["relationship_profile_id"] == profile.id
      private_ids = selected ? Array(turn.context["private_note_ids"]) : []
      vault_ids = selected ? Array(turn.context["vault_item_ids"]) : []
      with_owner_context(profile:) do
        context = ::MessageDrafts::ContextBuilder.new(relationship_profile: profile,
          include_private_notes: private_ids.any?, include_vault_context: vault_ids.any?,
          private_note_ids: private_ids, vault_item_ids: vault_ids).call
        RecordVersion.digest([ context.text, context.categories ])
      end
    end
    def self.with_owner_context(profile:, &block)
      Time.use_zone(OwnerLocalCalendar.time_zone_for(user: profile.user)) do
        I18n.with_locale(:en, &block)
      end
    end
    private_class_method :with_owner_context
  end
end
