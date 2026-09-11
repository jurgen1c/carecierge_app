module Concierge
  module Operations
    class Drafts < Generated
      SETTINGS = { draft_type: MessageDraft::DRAFT_TYPES, tone: MessageDraft::TONES,
        situation: :string, response_length: MessageDraft::RESPONSE_LENGTHS, formality: MessageDraft::FORMALITIES }.freeze

      def self.namespace = "drafts"

      def self.definitions
        [
          define("generate", description: "Prepare a message draft for the owner to review and send manually. Uses only sensitive items selected in this conversation.", fields: SCOPE_FIELDS.merge(SETTINGS),
            required: %w[draft_type tone], provider_work: true, capability: "draft_messages"),
          define("read", description: "Read available message revisions, newest first. Follow next_page to reach older revisions.", fields: SCOPE_FIELDS.merge(page: :integer), read_only: true),
          define("update", description: "Save the user's correction as a new immutable message draft revision. Never sends it.", fields: SCOPE_FIELDS.merge(SETTINGS).merge(content: :string), required: %w[content]),
          define("restore", description: "Restore an identified available message revision as a new revision.", fields: SCOPE_FIELDS.merge(revision_id: :uuid), required: %w[revision_id]),
          define("destroy", description: "Preview deleting the draft workspace and its revisions.", fields: SCOPE_FIELDS, confirmation: true)
        ]
      end

      def target
        @target ||= profile.message_draft
      end

      def generate(on_persist:)
        ::MessageDrafts::Generate.call(**generation_options, **attributes.symbolize_keys,
          on_persist: ->(revision) { on_persist.call(revision_result(revision)) })
      end

      def read
        authorize!(profile, :show)
        raise ActiveRecord::RecordNotFound unless target && target.relationship_mode == profile.relationship_mode
        matches = SearchRecords.call(scope: target.draft_revisions, page: arguments.fetch("page", 1), order: { position: :desc, id: :asc }) do |revision|
          GeneratedSources.visible?(revision, turn:)
        end
        { "records" => matches.records.map { |revision| revision_receipt(revision) }, "next_page" => matches.next_page }
      end

      def update
        authorize!(target || raise(ActiveRecord::RecordNotFound), :update)
        visible!(target.current_revision) if target.current_revision
        revision = target.save_edit!(**attributes.symbolize_keys,
          draft_type: arguments.fetch("draft_type", target.draft_type), tone: arguments.fetch("tone", target.tone),
          expected_relationship_mode: profile.relationship_mode)
        revision_result(revision)
      end

      def restore
        authorize!(target || raise(ActiveRecord::RecordNotFound), :update)
        revision = visible!(target.draft_revisions.find(arguments.fetch("revision_id")))
        revision_result(target.restore_revision!(revision))
      end

      def destroy
        authorize!(target || raise(ActiveRecord::RecordNotFound), :destroy)
        raise ActiveRecord::RecordNotFound unless target.relationship_mode == profile.relationship_mode
        target.destroy!
        { "deleted" => true }
      end

      private

      def revision_receipt(revision)
        receipt(revision, title: I18n.t("message_drafts.types.#{revision.message_draft.draft_type}"),
          body: revision.content, relationship_profile_id: profile.id, message_draft_id: revision.message_draft_id,
          revision: revision.position, certainty: "inferred", origin: revision.origin)
      end

      def revision_result(revision)
        GeneratedSources.mark_origin!(revision)
        { "record" => revision_receipt(revision) }
      end
    end
  end
end
