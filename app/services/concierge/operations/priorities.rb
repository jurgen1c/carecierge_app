module Concierge
  module Operations
    class Priorities < Base
      def self.namespace = "priorities"

      def self.definitions
        [ define("search", description: "Review the owner's current follow-ups, commitments, reminders, and ideas. Preserve priority sections and source certainty; these are recorded obligations or suggestions, not invented relationship scores.", fields: {}, read_only: true) ] +
          %w[dismiss snooze].map do |event|
            define(event, description: "#{event.capitalize} an identified priority card. This only changes its visibility; it does not complete the underlying commitment or reminder. Snooze returns tomorrow at 9 AM owner-local time.",
              fields: { item_key: :string }, required: %w[item_key])
          end
      end

      def profile
        item&.relationship_profile
      end

      def target
        item&.source
      end

      def item
        return unless arguments["item_key"]
        @item ||= DailyFeed::ForUser.find(user:, item_key: arguments["item_key"]) || raise(ActiveRecord::RecordNotFound)
      end

      def search
        records = DailyFeed::ForUser.call(user:).items.filter_map do |candidate|
          reference = item_receipt(candidate)
          next unless History.source_current?(reference, user:, turn:)
          Context.observe!(turn:, profile: candidate.relationship_profile)
          reference
        end
        { "records" => records, "as_of" => Time.current.iso8601, "time_zone" => Time.zone.name }
      end

      def dismiss
        authorize_state!
        FeedItemState.dismiss_for!(user:, item_key: item.key)
        { "record" => item_receipt(item), "presentation_state" => "dismissed" }
      end

      def snooze
        authorize_state!
        zone = OwnerLocalCalendar.time_zone_for(user:)
        tomorrow = Time.current.in_time_zone(zone).to_date + 1.day
        until_time = zone.local(tomorrow.year, tomorrow.month, tomorrow.day, 9)
        FeedItemState.snooze_for!(user:, item_key: item.key, until_time:)
        { "record" => item_receipt(item), "presentation_state" => "snoozed", "returns_at" => until_time.iso8601 }
      end

      private

      def authorize_state!
        raise ContextUnavailable unless History.source_current?(item_receipt(item), user:, turn:)
        authorize!(user.feed_item_states.find_or_initialize_by(item_key: item.key), :update)
      end

      def item_receipt(value)
        source = value.source.is_a?(MessageDraft) ? value.source.current_revision : value.source
        receipt(source, title: value.title, body: source.is_a?(DraftRevision) ? source.content.truncate(120) : value.detail,
          message_draft_id: source.is_a?(DraftRevision) ? source.message_draft_id : nil,
          relationship_profile_id: value.relationship_profile&.id, item_key: value.key,
          section: value.section, source_label: value.source_label, source_context: value.source_context,
          certainty: value.source_certainty, due_at: value.sort_at&.iso8601,
          suggested: value.suggestion.present?, action_kind: value.action_kind)
      end
    end
  end
end
