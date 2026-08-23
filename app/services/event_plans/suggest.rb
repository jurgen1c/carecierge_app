module EventPlans
  class Suggest
    MAX_RESULTS = 6
    TaskSnapshot = Data.define(:phase, :kind, :title, :details, :due_on, :completed)
    PlanSnapshot = Data.define(
      :title,
      :occasion_type,
      :starts_on,
      :budget_cents,
      :guest_list,
      :notes,
      :existing_tasks
    )

    def self.call(
      actor:,
      event_plan:,
      private_note_ids: [],
      vault_item_ids: [],
      vault_lease: nil,
      locale: I18n.locale,
      generator: LlmSuggester.new
    )
      new(
        actor:,
        event_plan:,
        private_note_ids:,
        vault_item_ids:,
        vault_lease:,
        locale:,
        generator:
      ).call
    end

    def initialize(**attributes)
      attributes.each { |key, value| instance_variable_set("@#{key}", value) }
      @private_note_ids = normalize_ids(attributes[:private_note_ids])
      @vault_item_ids = normalize_ids(attributes[:vault_item_ids])
      @locale = attributes[:locale].to_sym
    end

    def call
      generation_version, initial_context, plan_snapshot = prepare_generation!
      raw_suggestions = generator.generate(plan_snapshot:, sources: initial_context.sources, locale:)

      actor.with_lock do
        relationship_profile.with_lock do
          event_plan.with_lock do
            validate_plan!
            validate_vault_access!
            current_context = build_context
            reject_stale_generation!(generation_version:, initial_context:, current_context:)
            attributes = enrich_suggestions(raw_suggestions, sources: current_context.sources)
            raise GenerationError, "Event plan suggestion response had no usable steps" if attributes.empty?

            persisted = persist_suggestions!(attributes)
            preserve_plan_sources!(persisted)
            AuditEvent.record!(
              user: actor,
              actor:,
              action: "event_plan.suggestions_generated",
              target: event_plan,
              metadata: { result: "generated", count: persisted.length }
            )
            persisted
          end
        end
      end
    end

    private

    attr_reader :actor, :event_plan, :private_note_ids, :vault_item_ids, :vault_lease, :locale, :generator

    def relationship_profile = event_plan.relationship_profile

    def prepare_generation!
      actor.with_lock do
        relationship_profile.with_lock do
          event_plan.with_lock do
            validate_plan!
            validate_vault_access!
            context = build_context
            validate_selected_sources!(context)
            record_sensitive_access(context.categories)
            plan_snapshot = build_plan_snapshot(sources: context.sources)
            event_plan.increment!(:generation_version)
            [ event_plan.generation_version, context, plan_snapshot ]
          end
        end
      end
    end

    def validate_plan!
      raise ActiveRecord::RecordNotFound unless event_plan.user_id == actor.id
      raise ActiveRecord::RecordNotFound if relationship_profile.discarded?
      raise ActiveRecord::RecordNotFound unless event_plan.active?
      raise GenerationError, "Event plan locale was invalid" unless locale.to_s.in?(%w[en es])
    end

    def validate_vault_access!
      return if vault_item_ids.empty?
      return if vault_lease&.active_for?(actor)

      raise VaultAccessError, "Privacy vault access is required"
    end

    def validate_selected_sources!(context)
      found_ids = context.sources.map(&:id)
      expected_ids = private_note_ids.map { |id| "private_note:#{id}" } + vault_item_ids.map { |id| "vault:#{id}" }
      raise ActiveRecord::RecordNotFound unless (expected_ids - found_ids).empty?
    end

    def build_context
      ContextBuilder.new(
        event_plan:,
        private_note_ids:,
        vault_item_ids:,
        locale:
      ).call
    end

    def build_plan_snapshot(sources:)
      authorized_source_ids = sources.map(&:id)
      tasks = event_plan.plan_tasks.current.ordered.limit(50).filter_map do |task|
        persisted_source_ids = task.source_context.filter_map { |source| source["id"] }
        next unless persisted_source_ids.empty? || (persisted_source_ids - authorized_source_ids).empty?

        TaskSnapshot.new(
          phase: task.phase,
          kind: task.kind,
          title: task.title,
          details: task.details,
          due_on: task.due_on,
          completed: task.completed?
        )
      end.freeze
      PlanSnapshot.new(
        title: event_plan.title,
        occasion_type: event_plan.occasion_type,
        starts_on: event_plan.starts_on,
        budget_cents: event_plan.budget_cents,
        guest_list: event_plan.guest_list,
        notes: event_plan.notes,
        existing_tasks: tasks
      )
    end

    def reject_stale_generation!(generation_version:, initial_context:, current_context:)
      return if event_plan.generation_version == generation_version && initial_context.fingerprint == current_context.fingerprint

      raise GenerationSupersededError, "A newer request or plan change superseded these suggestions"
    end

    def enrich_suggestions(raw_suggestions, sources:)
      raise GenerationError, "Event plan suggestion response was invalid" unless raw_suggestions.is_a?(Array)

      source_by_id = sources.index_by(&:id)
      raw_suggestions.first(MAX_RESULTS).map do |raw|
        suggestion = raw.to_h.deep_stringify_keys
        phase = suggestion.fetch("phase")
        kind = suggestion.fetch("kind")
        title = suggestion.fetch("title").to_s.squish
        details = suggestion["details"].to_s.strip.presence
        raise GenerationError, "Event plan suggestion response was invalid" unless phase.in?(PlanTask::PHASES)
        raise GenerationError, "Event plan suggestion response was invalid" unless kind.in?(PlanTask::KINDS)
        raise GenerationError, "Event plan suggestion response was invalid" if title.blank?

        source_ids = suggestion.fetch("source_ids")
        raise GenerationError, "Event plan suggestion response was invalid" unless source_ids.is_a?(Array) && source_ids.present?

        cited_sources = source_ids.uniq.map do |source_id|
          source_by_id[source_id] || raise(GenerationError, "Event plan suggestion cited an unknown source")
        end
        {
          phase:,
          kind:,
          title:,
          details:,
          due_on: parse_date(suggestion["due_on"]),
          origin: "ai",
          source_context: cited_sources.map do |source|
            {
              "id" => source.id,
              "label" => source.label,
              "certainty" => source.certainty,
              "sensitive" => source.sensitive
            }
          end
        }
      end
    rescue KeyError, NoMethodError, TypeError
      raise GenerationError, "Event plan suggestion response was invalid"
    end

    def persist_suggestions!(attributes)
      next_position = event_plan.plan_tasks.maximum(:position).to_i + 1
      attributes.each_with_index.map do |task_attributes, offset|
        event_plan.plan_tasks.create!(task_attributes.merge(position: next_position + offset))
      end
    end

    def preserve_plan_sources!(tasks)
      sources = (event_plan.source_context + tasks.flat_map(&:source_context)).uniq { |source| source["id"] }
      event_plan.update!(source_context: sources.first(EventPlan::MAX_SOURCES))
    end

    def record_sensitive_access(categories)
      return if (categories & %w[private_notes vault]).empty?

      AuditEvent.record!(
        user: actor,
        actor:,
        action: "sensitive_record.accessed",
        target: relationship_profile,
        metadata: { result: "event_plan_suggestion" }
      )
      return unless categories.include?("vault")

      VaultAccessEvent.record_safely(event_type: "viewed", user: actor, relationship_profile:)
    end

    def parse_date(value)
      return if value.blank?

      Date.iso8601(value.to_s)
    rescue Date::Error
      raise GenerationError, "Event plan suggestion response was invalid"
    end

    def normalize_ids(values)
      Array(values).compact_blank.map(&:to_s).uniq.first(ContextBuilder::MAX_PER_KIND)
    end
  end
end
