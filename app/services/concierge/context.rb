module Concierge
  class Context
    MAX_SELECTIONS = 6

    def self.capture(user:, conversation:, selections: {}, vault_lease: nil)
      profile = conversation.relationship_profile
      raise ContextUnavailable unless conversation.context_available?

      private_note_ids = ids(selections, "private_note_ids")
      vault_item_ids = ids(selections, "vault_item_ids")
      raise ContextUnavailable if profile.nil? && (private_note_ids.any? || vault_item_ids.any?)
      if profile&.professional? && (private_note_ids.any? || vault_item_ids.any?)
        raise ContextUnavailable
      end
      if vault_item_ids.any? && !vault_lease&.active_for?(user)
        raise VaultLocked
      end

      notes = profile ? profile.relationship_notes.where(private: true).where.missing(:privacy_vault_item).where(id: private_note_ids).to_a : []
      items = profile ? profile.privacy_vault_items.suggestion_allowed.where(id: vault_item_ids).to_a : []
      raise ActiveRecord::RecordNotFound unless notes.size == private_note_ids.size && items.size == vault_item_ids.size

      {
        "relationship_profile_id" => profile&.id,
        "relationship_mode" => profile&.relationship_mode,
        "observed_profiles" => profile ? { profile.id => profile_snapshot(profile) } : {},
        "private_note_ids" => private_note_ids,
        "private_context_ids" => private_note_ids,
        "vault_item_ids" => vault_item_ids,
        "selected_versions" => (notes + items).to_h { |record| [ record.id, RecordVersion.for(record) ] },
        "vault_lease" => vault_item_ids.any? ? vault_lease.to_session : nil
      }
    end

    def self.verify!(turn:)
      conversation = turn.conversation
      user = conversation.user
      user.with_lock("FOR NO KEY UPDATE") do
        raise ContextUnavailable unless conversation.reload.context_available?

        snapshot = turn.context
        verify_authored_notes!(user:, snapshot:)
        snapshot.fetch("observed_profiles", {}).each do |id, expected|
          observed = user.relationship_profiles.active.find(id)
          observed.with_lock do
            raise ContextUnavailable unless profile_snapshot(observed) == expected
          end
        end
        profile = conversation.relationship_profile
        if snapshot["relationship_profile_id"] != profile&.id || snapshot["relationship_mode"] != profile&.relationship_mode
          raise ContextUnavailable
        end
        next true unless profile

        profile.with_lock do
          current = capture(user:, conversation:, selections: snapshot,
            vault_lease: PrivacyVault::Lease.from_session(snapshot["vault_lease"]))
          raise ContextUnavailable unless current["selected_versions"] == snapshot.fetch("selected_versions", {})
          true
        end
      end
    rescue ActiveRecord::RecordNotFound
      raise ContextUnavailable
    end

    def self.observe!(turn:, profile:)
      return unless profile
      snapshot = turn.context.deep_dup
      snapshot["observed_profiles"] ||= {}
      snapshot["observed_profiles"][profile.id] = profile_snapshot(profile)
      turn.update!(context: snapshot)
    end

    # Only the authorized notes operation can advance its own source version.
    # Newly supplied private content is readable for this turn, not future turns.
    def self.record_note_change!(turn:, note:)
      snapshot = turn.context.deep_dup
      snapshot["private_context_ids"] = private_note_provenance(snapshot)
      snapshot["private_context_ids"] |= [ note.id ] if note.private?
      selected = Array(snapshot["private_note_ids"])
      versions = snapshot.fetch("selected_versions", {})
      authored = snapshot.fetch("authored_private_notes", {})
      if note.destroyed? || !note.private?
        selected.delete(note.id)
        versions.delete(note.id)
        authored.delete(note.id)
      elsif selected.include?(note.id)
        versions[note.id] = RecordVersion.for(note)
      else
        authored[note.id] = { "relationship_profile_id" => note.relationship_profile_id, "version" => RecordVersion.for(note) }
        raise LimitReached if authored.size > MAX_SELECTIONS
      end
      turn.update!(context: snapshot.merge("private_note_ids" => selected, "selected_versions" => versions, "authored_private_notes" => authored))
    end

    def self.private_note_provenance(snapshot)
      (Array(snapshot["private_context_ids"]) + Array(snapshot["private_note_ids"]) +
        snapshot.fetch("authored_private_notes", {}).keys).uniq
    end

    def self.verify_authored_notes!(user:, snapshot:)
      snapshot.fetch("authored_private_notes", {}).each do |id, expected|
        profile = user.relationship_profiles.active.find(expected.fetch("relationship_profile_id"))
        note = profile.relationship_notes.where.missing(:privacy_vault_item).find(id)
        raise ContextUnavailable unless note.private? && RecordVersion.for(note) == expected.fetch("version")
      end
    end
    private_class_method :verify_authored_notes!

    def self.profile_snapshot(profile)
      { "mode" => profile.relationship_mode, "work_context" => profile.professional_context }
    end

    def self.ids(selections, key)
      values = selections.fetch(key, [])
      raise InvalidArguments unless values.is_a?(Array) && values.size <= MAX_SELECTIONS
      raise InvalidArguments unless values.all? { |value| value.is_a?(String) && value.match?(RelationshipMemorySearch::SearchQuery::ID_FORMAT) }

      values.uniq
    end
    private_class_method :ids
  end
end
