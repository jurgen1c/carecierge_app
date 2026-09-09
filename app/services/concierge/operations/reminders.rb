module Concierge
  module Operations
    class Reminders < Base
      REQUIRES_PROFILE_ID = false
      CLEARABLE_FIELDS = %w[notes].freeze
      ASSOCIATION = :reminders
      FIELDS = { relationship_profile_id: :uuid, title: :string, notes: :string, scheduled_at: :datetime,
        reminder_type: Reminder::REMINDER_TYPES, priority: Reminder::PRIORITIES, recurrence: Reminder::RECURRENCES,
        important_date_id: :uuid, commitment_id: :uuid, event_plan_id: :uuid, plan_task_id: :uuid,
        vendor_quote_id: :uuid, booking_id: :uuid, booking_milestone: Reminder::BOOKING_MILESTONES }.freeze

      def self.namespace = "reminders"

      def self.definitions
        scope = { relationship_profile_id: :uuid }
        [ define("search", description: "Find the owner's reminders, with actual scheduled times and completion states. Follow next_page for older records.", fields: scope.merge(query: :string, page: :integer), read_only: true),
         define("read", description: "Read an identified reminder.", fields: scope.merge(id: :uuid), required: %w[id], read_only: true),
         define("create", description: "Schedule an internal reminder at the exact confirmed owner-local time. Link to a same-person commitment, date, or plan when relevant. Clarify missing time before calling.",
           fields: FIELDS, required: %w[title scheduled_at], capability: "send_reminders"),
         define("update", description: "Change a reminder's text or exact schedule, preserving unspecified source links.", fields: FIELDS.merge(id: :uuid), required: %w[id], capability: "send_reminders"),
         define("snooze", description: "Snooze this reminder until a specific future time.", fields: scope.merge(id: :uuid, until_time: :datetime), required: %w[id until_time], capability: "send_reminders"),
         define("complete", description: "Complete this occurrence; recurring reminders advance according to their saved schedule.", fields: scope.merge(id: :uuid), required: %w[id], capability: "send_reminders"),
         define("destroy", description: "Preview deleting this reminder; requires inline confirmation.", fields: scope.merge(id: :uuid), required: %w[id], confirmation: true) ]
      end

      def profile
        @profile ||= if arguments["id"]
          reminder = user.reminders.find(arguments["id"])
          if turn.context["relationship_mode"] == "professional" && reminder.relationship_profile_id.nil?
            raise ContextUnavailable
          end
          if arguments["relationship_profile_id"] && reminder.relationship_profile_id != arguments["relationship_profile_id"]
            raise ActiveRecord::RecordNotFound
          end
          reminder.relationship_profile
        elsif arguments["relationship_profile_id"].presence || turn.conversation.relationship_profile_id
          super
        end
      end

      def scope
        return profile.work_context.selected("reminders") if profile&.professional?
        records = user.reminders.where(relationship_profile_id: nil).or(
          user.reminders.where(relationship_profile_id: user.relationship_profiles.active.where(relationship_mode: "personal").select(:id)))
        profile ? records.where(relationship_profile_id: profile.id) : records
      end

      def target
        @target ||= scope.find(arguments["id"]) if arguments["id"]
      end

      def with_record_locks
        plan = target&.event_plan || (arguments["event_plan_id"] && user.event_plans.for_active_relationships.visible.find(arguments["event_plan_id"]))
        plan ? plan.with_mutation_lock { super } : super
      end

      def search
        authorize!(Reminder, :index)
        matches = SearchRecords.call(scope:, predicate: :title_or_notes_cont, query: arguments["query"], page: arguments.fetch("page", 1))
        { "records" => matches.records.map { |record| reminder_receipt(record) }, "next_page" => matches.next_page }
      end

      def read
        authorize!(target, :update)
        { "record" => reminder_receipt(target) }
      end

      def create
        record = user.reminders.new(relationship_profile: profile, time_zone: OwnerLocalCalendar.time_zone_for(user:).name)
        authorize!(record, :create)
        if profile&.professional?
          ProfessionalScope.create_record!(handler: self, record:) { persist!(record, "created") }
        else
          persist!(record, "created")
        end
        { "record" => reminder_receipt(record) }
      end

      def update
        authorize!(target, :update)
        persist!(target, "updated")
        { "record" => reminder_receipt(target) }
      end

      def snooze
        authorize!(target, :snooze)
        time = Time.iso8601(arguments.fetch("until_time"))
        raise InvalidArguments unless time > Time.current
        track(target, "snoozed") { target.snooze!(until_time: time) }
        { "record" => reminder_receipt(target) }
      end

      def complete
        authorize!(target, :complete)
        track(target, "completed") { target.complete! }
        { "record" => reminder_receipt(target) }
      end

      def destroy
        authorize!(target, :destroy)
        value = reminder_receipt(target)
        AuditEvents::Track.call(user:, actor: user, action: "reminder.deleted", target: nil) { target.destroy! }
        { "record" => value, "deleted" => true }
      end

      private

      def persist!(record, event)
        record.assign_attributes(attributes.except(*%w[important_date_id commitment_id event_plan_id plan_task_id vendor_quote_id booking_id]))
        %w[important_date commitment].each do |name|
          next unless arguments["#{name}_id"]
          raise InvalidArguments unless profile
          record.public_send("#{name}=", Sources.scope(profile:, association: name.pluralize.to_sym, turn:).find(arguments["#{name}_id"]))
        end
        if arguments["event_plan_id"]
          raise InvalidArguments unless profile
          record.event_plan = Sources.scope(profile:, association: :event_plans, turn:).where(user:, status: "active").find(arguments["event_plan_id"])
        end
        if arguments["plan_task_id"]
          raise InvalidArguments unless record.event_plan
          record.plan_task = record.event_plan.plan_tasks.current.incomplete.find(arguments["plan_task_id"])
          raise ActiveRecord::RecordNotFound unless OccasionSources.task_visible?(record.plan_task, turn:)
        end
        %w[vendor_quote booking].each do |name|
          next unless arguments["#{name}_id"]
          raise InvalidArguments unless record.event_plan
          related = user.public_send(name.pluralize).where(event_plan: record.event_plan).find(arguments["#{name}_id"])
          if related.is_a?(VendorQuote)
            raise ActiveRecord::RecordNotFound unless VendorSources.vendor_scope(profile:, user:).exists?(id: related.vendor_id)
          end
          record.public_send("#{name}=", related)
        end
        track(record, event) do
          raise ActiveRecord::RecordInvalid, record unless Suggestions::CompleteReminderAction.call(reminder: record, suggestion: nil, user:)
        end
      end

      def reminder_receipt(record)
        receipt(record, title: record.title, body: record.notes, scheduled_at: record.local_scheduled_at&.iso8601,
          time_zone: record.time_zone, recurrence: record.recurrence, state: record.status,
          effective_delivery_at: record.effective_delivery_at.iso8601, commitment_id: record.commitment_id,
          event_plan_id: record.event_plan_id, plan_task_id: record.plan_task_id, important_date_id: record.important_date_id)
      end

      def track(record, event, &block)
        AuditEvents::Track.call(user:, actor: user, action: "reminder.#{event}", target: record, &block)
      end
    end
  end
end
