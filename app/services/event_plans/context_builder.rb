require "digest"
require "json"

module EventPlans
  class ContextBuilder
    MAX_SOURCES = 40
    MAX_PER_KIND = 8
    MAX_SOURCE_CHARACTERS = 700
    MAX_SENSITIVE_SOURCE_CHARACTERS = 400
    MAX_TOTAL_CHARACTERS = 12_000
    MAX_PRIOR_TASK_CANDIDATES = 50

    Source = Data.define(:id, :kind, :content, :certainty, :label, :sensitive)
    Result = Data.define(:sources, :categories, :fingerprint)

    def initialize(event_plan:, private_note_ids: [], vault_item_ids: [], locale: I18n.locale)
      @event_plan = event_plan
      @relationship_profile = event_plan.relationship_profile
      @private_note_ids = normalize_ids(private_note_ids)
      @vault_item_ids = normalize_ids(vault_item_ids)
      @locale = locale.to_sym
      @as_of = OwnerLocalCalendar.date_for(user: relationship_profile.user)
    end

    def call
      I18n.with_locale(locale) do
        selected_sources = bound_sources(sources)
        Result.new(
          sources: selected_sources,
          categories: selected_sources.map { |source| category_for(source.kind) }.uniq,
          fingerprint: Digest::SHA256.hexdigest(JSON.generate(
            event_plan: plan_fingerprint_payload,
            sources: selected_sources.map(&:to_h)
          ))
        )
      end
    end

    private

    attr_reader :event_plan, :relationship_profile, :private_note_ids, :vault_item_ids, :locale, :as_of

    def sources
      private_sources = selected_private_note_sources
      vault_sources = selected_vault_sources
      ordinary_sources = [ profile_source ] + preference_sources + memory_sources + important_date_sources +
        commitment_sources + gift_sources + desire_sources + public_note_sources
      authorized_source_ids = (private_sources + vault_sources + ordinary_sources).index_by(&:id)
      current_priority_sources, secondary_sources = ordinary_sources.partition do |source|
        source.kind.in?(%w[relationship constraint])
      end

      private_sources + vault_sources + current_priority_sources +
        prior_anniversary_plan_sources(authorized_source_ids:) + secondary_sources
    end

    def profile_source
      source(
        id: "profile:#{relationship_profile.id}",
        kind: "relationship",
        content: relationship_profile.relationship_type_label,
        certainty: "confirmed"
      )
    end

    def preference_sources
      relationship_profile.relationship_preferences
        .order(Arel.sql(<<~SQL.squish), :created_at, :id)
          CASE
            WHEN preference_type IN ('constraint', 'negative')
              OR category IN ('boundaries', 'allergies', 'cultural_constraints')
            THEN 0
            ELSE 1
          END
        SQL
        .limit(MAX_PER_KIND)
        .map do |preference|
          kind = hard_constraint_preference?(preference) ? "constraint" : "preference"
          source(
            id: "preference:#{preference.id}",
            kind:,
            content: "#{preference.category}: #{preference.preference_type}: #{preference.key}: #{preference.value}",
            certainty: preference.confidence == "confirmed" ? "confirmed" : "inferred"
          )
        end
    end

    def hard_constraint_preference?(preference)
      preference.preference_type.in?(%w[constraint negative]) ||
        preference.category.in?(%w[boundaries allergies cultural_constraints])
    end

    def memory_sources
      relationship_profile.memory_records
        .unprotected
        .where(status: %w[active corrected])
        .where("stale_after IS NULL OR stale_after >= ?", as_of)
        .order(:created_at, :id)
        .limit(MAX_PER_KIND)
        .map do |memory|
          source(
            id: "memory:#{memory.id}",
            kind: "memory",
            content: "#{memory.title}: #{memory.body}",
            certainty: memory.source == "ai_inferred" || memory.confidence.in?(%w[low inferred]) ? "inferred" : "confirmed"
          )
        end
    end

    def important_date_sources
      relationship_profile.association(:important_dates).reset
      dates = relationship_profile.upcoming_important_dates(as_of:).sort_by do |important_date|
        [ important_date.next_occurrence_on(as_of:), important_date.display_title.downcase, important_date.id ]
      end.first(MAX_PER_KIND)

      dates.map do |important_date|
        occurrence = important_date.next_occurrence_on(as_of:)
        source(
          id: "important_date:#{important_date.id}",
          kind: "important_date",
          content: "#{important_date.display_title}: #{occurrence.iso8601}",
          certainty: "confirmed"
        )
      end
    end

    def commitment_sources
      relationship_profile.commitments.where(status: "open").ordered.limit(MAX_PER_KIND).map do |commitment|
        source(
          id: "commitment:#{commitment.id}",
          kind: "commitment",
          content: [ commitment.title, commitment.due_on&.iso8601 ].compact.join(": "),
          certainty: "confirmed"
        )
      end
    end

    def gift_sources
      relationship_profile.gifts.ordered.order(:id).limit(MAX_PER_KIND).map do |gift|
        source(
          id: "gift:#{gift.id}",
          kind: "gift",
          content: [ gift.name, gift.status, gift.occasion, gift.reaction ].compact_blank.join("; "),
          certainty: "confirmed"
        )
      end
    end

    def desire_sources
      relationship_profile.desires.where(status: Desire::EDITABLE_STATUSES).ordered.order(:id).limit(MAX_PER_KIND).map do |desire|
        source(
          id: "desire:#{desire.id}",
          kind: "desire",
          content: [ desire.title, desire.notes ].compact_blank.join(": "),
          certainty: desire.source == "manual" ? "confirmed" : "inferred"
        )
      end
    end

    def public_note_sources
      note_sources(
        relationship_profile.relationship_notes.where(private: false).where.missing(:privacy_vault_item),
        kind: "public_note",
        sensitive: false
      )
    end

    def prior_anniversary_plan_sources(authorized_source_ids:)
      ids = event_plan.prior_anniversary_context.filter_map do |entry|
        entry["id"].delete_prefix("event_plan:") if entry["id"].to_s.start_with?("event_plan:")
      end
      return [] if ids.empty?

      relationship_profile.event_plans
        .where(id: ids, occasion_type: "anniversary", status: %w[completed archived])
        .order(starts_on: :desc, created_at: :desc, id: :desc)
        .limit(MAX_PER_KIND)
        .map do |prior_plan|
          reusable_tasks = prior_plan.plan_tasks.current.ordered
            .limit(MAX_PRIOR_TASK_CANDIDATES)
            .select { |task| reusable_prior_task?(task, authorized_source_ids:) }
            .first(6)
          content = ([ prior_plan.title ] + reusable_tasks.map(&:title)).join("; ")
          sensitive = reusable_tasks.any? do |task|
            sensitive_prior_task?(task, authorized_source_ids:)
          end
          source(
            id: prior_plan_source_id(
              prior_plan:,
              reusable_tasks:,
              authorized_source_ids:,
              content:,
              sensitive:
            ),
            kind: "prior_anniversary_plan",
            content:,
            certainty: "inferred",
            sensitive:
          )
        end
    end

    def prior_plan_source_id(prior_plan:, reusable_tasks:, authorized_source_ids:, content:, sensitive:)
      fingerprint = Digest::SHA256.hexdigest(JSON.generate(
        content:,
        sensitive:,
        tasks: reusable_tasks.map do |task|
          {
            id: task.id,
            sources: task.source_context.filter_map do |task_source|
              authorized_source_ids[task_source["id"]]&.to_h
            end.sort_by { |source| source.fetch(:id) }
          }
        end
      ))
      "prior_event_plan:#{prior_plan.id}:#{fingerprint}"
    end

    def reusable_prior_task?(task, authorized_source_ids:)
      return true unless task.origin == "ai"
      return false if task.source_context.empty?

      task.source_context.all? do |task_source|
        task_source.is_a?(Hash) && authorized_source_ids.key?(task_source["id"])
      end
    end

    def sensitive_prior_task?(task, authorized_source_ids:)
      task.source_context.any? do |task_source|
        task_source.is_a?(Hash) && authorized_source_ids[task_source["id"]]&.sensitive
      end
    end

    def selected_private_note_sources
      return [] if private_note_ids.empty?

      note_sources(
        relationship_profile.relationship_notes.where(private: true, id: private_note_ids).where.missing(:privacy_vault_item),
        kind: "private_note",
        sensitive: true
      )
    end

    def selected_vault_sources
      return [] if vault_item_ids.empty?

      relationship_profile.privacy_vault_items.suggestion_allowed.where(id: vault_item_ids).ordered.limit(MAX_PER_KIND).map do |item|
        source(
          id: "vault:#{item.id}",
          kind: "vault",
          content: "#{item.display_title}: #{plain_text(item.display_body)}",
          certainty: item.protectable.is_a?(MemoryRecord) && item.protectable.source == "ai_inferred" ? "inferred" : "confirmed",
          sensitive: true
        )
      end
    end

    def note_sources(scope, kind:, sensitive:)
      scope.includes(:rich_text_body).order(:created_at, :id).limit(MAX_PER_KIND).filter_map do |note|
        content = note.body.to_plain_text.squish
        next if content.blank?

        source(id: "#{kind}:#{note.id}", kind:, content:, certainty: "confirmed", sensitive:)
      end
    end

    def source(id:, kind:, content:, certainty:, sensitive: false)
      Source.new(
        id:,
        kind:,
        content: content.to_s.squish.first(sensitive ? MAX_SENSITIVE_SOURCE_CHARACTERS : MAX_SOURCE_CHARACTERS),
        certainty:,
        label: label(kind).first(240),
        sensitive:
      )
    end

    def bound_sources(candidates)
      remaining = MAX_TOTAL_CHARACTERS
      candidates.first(MAX_SOURCES).filter_map do |candidate|
        next if remaining <= 0 || candidate.content.blank?

        content = candidate.content.first(remaining)
        remaining -= content.length
        candidate.with(content:)
      end
    end

    def plan_fingerprint_payload
      event_plan.reload
      {
        id: event_plan.id,
        title: event_plan.title,
        occasion_type: event_plan.occasion_type,
        tone: event_plan.tone,
        effort_level: event_plan.effort_level,
        starts_on: event_plan.starts_on&.iso8601,
        source_context: event_plan.source_context,
        budget_cents: event_plan.budget_cents,
        guest_list: event_plan.guest_list,
        notes: event_plan.notes,
        tasks: event_plan.plan_tasks.reload.map do |task|
          [ task.id, task.phase, task.kind, task.title, task.details, task.due_on&.iso8601, task.completed_at&.iso8601 ]
        end
      }
    end

    def category_for(kind)
      { "private_note" => "private_notes", "public_note" => "public_notes" }.fetch(kind, kind)
    end

    def label(kind)
      I18n.with_locale(locale) { I18n.t("event_plans.sources.#{kind}", default: kind.humanize) }
    end

    def plain_text(value)
      ActionText::Content.new(value.to_s).to_plain_text.squish
    end

    def normalize_ids(values)
      Array(values).compact_blank.map(&:to_s).uniq.first(MAX_PER_KIND)
    end
  end
end
