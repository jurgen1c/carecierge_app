module SocialContextNotes
  class Analyze
    def self.call(actor:, note:, expected_lock_version:, locale: I18n.locale, analyzer: OpenAiAnalyzer.new)
      new(actor:, note:, expected_lock_version:, locale:, analyzer:).call
    end

    def initialize(actor:, note:, expected_lock_version:, locale:, analyzer:)
      @actor = actor
      @note = note
      @expected_lock_version = expected_lock_version
      @locale = locale
      @analyzer = analyzer
    end

    def call
      version, input = prepare_analysis!
      result = analyzer.analyze(input:, locale:)
      persist_draft!(version:, result:)
    end

    private

    attr_reader :actor, :note, :expected_lock_version, :locale, :analyzer

    def prepare_analysis!
      note.relationship_profile.with_lock do
        note.with_lock do
          raise ActiveRecord::RecordNotFound unless note.relationship_profile.user_id == actor.id
          raise ActiveRecord::RecordNotFound if note.relationship_profile.discarded?
          raise ActiveRecord::StaleObjectError.new(note, "analyze") unless note.lock_version == expected_lock_version

          input = AnalysisInput.new(
            text: note.body.to_plain_text,
            image_blob_ids: note.image_blobs.map(&:id)
          )
          message_context_changed = note.clear_ai_analysis!
          note.relationship_profile.cancel_in_flight_message_draft_generations! if message_context_changed

          [ note.lock_version, input ]
        end
      end
    end

    def persist_draft!(version:, result:)
      actor.with_lock do
        note.relationship_profile.with_lock do
          note.with_lock do
            raise ActiveRecord::RecordNotFound if note.relationship_profile.discarded?
            raise ActiveRecord::StaleObjectError.new(note, "analyze") unless note.lock_version == version

            previous_message_draft_context = note.message_draft_context_signature
            note.update!(
              interpretation: result.fetch(:interpretation),
              interpretation_status: "draft",
              suggested_uses: result.fetch(:suggested_uses),
              analyzed_at: Time.current
            )
            if previous_message_draft_context != note.message_draft_context_signature
              note.relationship_profile.cancel_in_flight_message_draft_generations!
            end
            AuditEvent.record!(
              user: actor,
              actor:,
              action: "automation.performed",
              target: note.relationship_profile,
              metadata: { capability: "analyze_uploaded_social_content", result: "draft_created" }
            )
            note
          end
        end
      end
    end
  end
end
