module Concierge
  module Operations
    class Touches < Base
      FIELDS = { checklist_id: :uuid }.freeze
      CONTENT_FIELDS = { category: PersonalTouchItem::CATEGORIES, title: :string, details: :string }.freeze

      def self.namespace = "touches"

      def self.definitions
        [
          define("prepare", description: "Start or retrieve the personal-touch checklist for exactly one event plan or important date.",
            fields: { event_plan_id: :uuid, important_date_id: :uuid }),
          define("search", description: "Read a checklist's available personal touches and progress in checklist order. Follow next_page to continue.", fields: FIELDS.merge(page: :integer), required: %w[checklist_id], read_only: true),
          define("create", description: "Add an explicitly requested personal touch to this checklist.", fields: FIELDS.merge(CONTENT_FIELDS), required: %w[checklist_id title category]),
          define("update", description: "Correct a personal touch with the user's own wording.", fields: FIELDS.merge(CONTENT_FIELDS).merge(id: :uuid), required: %w[checklist_id id])
        ] + %w[complete reopen dismiss move_up move_down].map do |event|
          define(event, description: "#{event.humanize} an identified personal touch.", fields: FIELDS.merge(id: :uuid), required: %w[checklist_id id])
        end
      end

      def checklist
        return @checklist if @checklist
        return unless arguments["checklist_id"]
        @checklist ||= Pundit.policy_scope!(user, PersonalTouchChecklist).find(arguments["checklist_id"])
      end

      def moment
        return checklist.moment if checklist
        ids = arguments.slice("event_plan_id", "important_date_id")
        raise InvalidArguments unless ids.size == 1
        @moment ||= if ids["event_plan_id"]
          user.event_plans.for_active_relationships.visible.find(ids["event_plan_id"])
        else
          ImportantDate.where(relationship_profile_id: user.relationship_profiles.active.select(:id)).find(ids["important_date_id"])
        end
      end

      def profile
        record = moment.relationship_profile
        raise ActiveRecord::RecordNotFound if record.archived?
        if moment.is_a?(EventPlan)
          raise ActiveRecord::RecordNotFound unless OccasionSources.plan_visible?(moment, turn:)
        elsif record.professional?
          raise ActiveRecord::RecordNotFound unless record.work_context.selected("important_dates").exists?(id: moment.id)
        end
        record
      end

      def target
        return unless arguments["id"]
        return @target if @target
        item = checklist.personal_touch_items.visible.find(arguments["id"])
        raise ActiveRecord::RecordNotFound unless OccasionSources.touch_visible?(item, turn:)
        @target = item
      end

      def with_record_locks
        if checklist
          checklist.with_mutation_lock { super }
        else
          moment.with_lock { yield }
        end
      end

      def prepare
        candidate = PersonalTouchChecklist.new(relationship_profile: profile)
        authorize!(candidate, :create)
        @checklist = ::PersonalTouchChecklists::Create.call(actor: user, moment:, locale: turn.locale)
        search
      end

      def search
        authorize!(checklist, :show)
        matches = SearchRecords.call(scope: checklist.personal_touch_items.visible, page: arguments.fetch("page", 1), order: { position: :asc, created_at: :asc, id: :asc }) do |item|
          OccasionSources.touch_visible?(item, turn:)
        end
        { "checklist_id" => checklist.id, "progress" => profile.professional? ? nil : checklist.progress,
          "records" => matches.records.map { |item| item_receipt(item) }, "next_page" => matches.next_page }
      end

      def create
        verify_gift_category!
        item = checklist.personal_touch_items.new(attributes.slice(*CONTENT_FIELDS.keys.map(&:to_s)).merge(
          origin: "manual", status: "active", source_context: [], position: (checklist.personal_touch_items.maximum(:position) || -1) + 1))
        authorize!(item, :create)
        track("created") { item.save! }
        { "record" => item_receipt(item) }
      end

      def update
        verify_gift_category!
        authorize!(target, :update)
        track("updated") { target.update!(attributes.slice(*CONTENT_FIELDS.keys.map(&:to_s)).merge(origin: "manual", source_context: [])) }
        { "record" => item_receipt(target) }
      end

      %w[complete reopen dismiss move_up move_down].each do |event|
        define_method(event) do
          authorize!(target, event)
          audit = { "complete" => "completed", "reopen" => "reopened", "dismiss" => "dismissed" }.fetch(event, "reordered")
          original_position = target.position
          track(audit) { target.public_send("#{event}!") }
          result = { "record" => item_receipt(target), "archived" => event == "dismiss" }
          if event.in?(%w[move_up move_down]) && original_position != target.position
            sibling_ids = checklist.personal_touch_items.where(position: original_position,
              id: History.referenced_ids(turn, record_type: "PersonalTouchItem")).pluck(:id)
            result["superseded"] = sibling_ids.map { |id| { "record_type" => "PersonalTouchItem", "id" => id } }
          end
          result
        end
      end

      private

      def verify_gift_category!
        return unless profile.professional? && arguments["category"] == "gift"
        raise PermissionDenied unless profile.professional_gifts_allowed?
      end

      def track(event, &block)
        AuditEvents::Track.call(user:, actor: user, action: "personal_touch_item.#{event}", target: profile, &block)
      end

      def item_receipt(item)
        receipt(item, title: item.title, body: item.details, relationship_profile_id: profile.id,
          checklist_id: checklist.id, event_plan_id: checklist.event_plan_id, important_date_id: checklist.important_date_id,
          state: item.status, category: item.category, position: item.position, sources: item.source_context,
          certainty: item.manual? ? "confirmed" : "inferred")
      end
    end
  end
end
