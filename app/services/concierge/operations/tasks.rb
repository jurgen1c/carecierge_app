module Concierge
  module Operations
    class Tasks < ProfileRecords
      REQUIRES_PROFILE_ID = false
      CLEARABLE_FIELDS = %w[due_on details].freeze
      NAMESPACE = "tasks"
      ASSOCIATION = :plan_tasks
      FIELDS = { phase: PlanTask::PHASES, kind: PlanTask::KINDS, title: :string, details: :string, due_on: :date }.freeze
      REQUIRED = %w[title phase kind event_plan_id].freeze
      SEARCH = :title_or_details_cont
      TITLE = :title
      BODY = :details
      SCOPE_FIELDS = { relationship_profile_id: :uuid, event_plan_id: :uuid }.freeze

      def self.definitions
        # These fields are fixed at the adapter, never model or scope names from a tool argument.
        super.map do |operation|
          Operation.new(name: operation.name, description: operation.description, handler_class: self,
            fields: operation.fields.merge("event_plan_id" => :uuid), required: (operation.required + %w[event_plan_id]).uniq,
            read_only: operation.read_only, confirmation: operation.confirmation, nullable: operation.nullable)
        end + %w[complete reopen].map do |event|
          define(event, description: "#{event.capitalize} a task in an identified event plan.",
            fields: SCOPE_FIELDS.merge(id: :uuid), required: %w[id event_plan_id])
        end
      end

      def plan
        @plan ||= user.event_plans.for_active_relationships.visible.find(arguments.fetch("event_plan_id"))
      end

      def profile
        selected = arguments["relationship_profile_id"]
        raise ActiveRecord::RecordNotFound if selected && selected != plan.relationship_profile_id
        raise ActiveRecord::RecordNotFound unless OccasionSources.plan_visible?(plan, turn:)
        plan.relationship_profile
      end

      def scope
        plan.plan_tasks.current.where.missing(:booking)
      end

      def target
        record = super
        raise ActiveRecord::RecordNotFound if record && !OccasionSources.task_visible?(record, turn:)
        record
      end

      def with_record_locks
        plan.with_mutation_lock { super }
      end

      def create
        record = plan.plan_tasks.new(attributes.except("event_plan_id").merge(origin: "manual", source_context: []))
        authorize!(record, :create)
        record.position = plan.plan_tasks.maximum(:position).to_i + 1
        record.save!
        plan.increment!(:generation_version)
        { "record" => record_receipt(record) }
      end

      def destroy
        authorize!(target, :destroy)
        value = record_receipt(target)
        target.remove_from_plan!
        plan.increment!(:generation_version)
        { "record" => value, "deleted" => true }
      end

      %i[complete reopen].each do |event|
        define_method(event) do
          authorize!(target, event)
          target.public_send("#{event}!")
          { "record" => record_receipt(target) }
        end
      end

      def record_receipt(record)
        self.class.receipt_for(record)
      end

      def self.receipt_for(record)
        { "record_type" => "PlanTask", "id" => record.id, "version" => RecordVersion.for(record),
          "relationship_profile_id" => record.event_plan.relationship_profile_id, "event_plan_id" => record.event_plan_id,
          "title" => record.title, "body" => record.details, "due_on" => record.due_on&.iso8601,
          "completed" => record.completed?, "origin" => record.origin, "certainty" => record.origin == "ai" ? "inferred" : "confirmed" }
      end

      private

      def search_visible?(record)
        OccasionSources.task_visible?(record, turn:)
      end

      def persist!(record)
        record.update!(attributes.except("event_plan_id"))
        plan.increment!(:generation_version)
      end
    end
  end
end
