module Concierge
  class OccasionSources
    SOURCE_ASSOCIATIONS = { "timeline" => :timeline_entries, "commitment" => :commitments,
      "important_date" => :important_dates, "preference" => :relationship_preferences,
      "desire" => :desires, "gift" => :gifts, "social_context" => :social_context_notes }.freeze

    def self.sources_authorized?(sources, profile_id:, turn:, plan: nil, visited: [], locale: turn.locale, memo: {})
      profile = turn.conversation.user.relationship_profiles.active.find_by(id: profile_id)
      return false unless profile
      if profile&.professional?
        selected_ids = profile.work_context.entries.map(&:id)
        return Array(sources).all? { |source| !source["sensitive"] && selected_ids.include?(source["id"]) }
      end
      Array(sources).all? do |source|
        id = source["id"].to_s
        if id.start_with?("public_note:")
          Sources.scope(profile:, association: :relationship_notes, turn:).exists?(id: id.delete_prefix("public_note:"))
        elsif id.start_with?("memory:")
          Sources.scope(profile:, association: :memory_records, turn:).exists?(id: id.delete_prefix("memory:"))
        elsif id.start_with?("private_note:")
          turn.context["relationship_profile_id"] == profile_id && Array(turn.context["private_note_ids"]).include?(id.delete_prefix("private_note:"))
        elsif id.start_with?("vault:")
          item_id = id.delete_prefix("vault:")
          turn.context["relationship_profile_id"] == profile_id && Array(turn.context["vault_item_ids"]).include?(item_id) &&
            profile.privacy_vault_items.suggestion_allowed.exists?(id: item_id)
        else
          kind, record_id = id.split(":", 3)
          next false if source["sensitive"]
          if kind == "profile"
            record_id == profile.id
          elsif kind == "prior_event_plan"
            plan && plan.relationship_profile_id == profile.id &&
              [ locale.to_s, "en", "es" ].uniq.any? do |source_locale|
                TaskSources.context(plan:, turn:, locale: source_locale, visited:, memo:).sources.any? { |current| current.id == id }
              end
          else
            association = SOURCE_ASSOCIATIONS[kind]
            association && Sources.scope(profile:, association:, turn:).exists?(id: record_id)
          end
        end
      end
    end

    def self.task_visible?(task, turn:)
      return false unless task && turn && !task.superseded? && plan_visible?(task.event_plan, turn:)
      return false unless TaskSources.input_visible?(task, turn:)
      Context.verify!(turn:)
      true
    rescue Error, ActiveRecord::RecordNotFound
      false
    end

    def self.backup_visible?(option, turn:, check_origin: true)
      return false unless option && turn
      backup = option.backup_plan
      plan = backup.event_plan
      return false unless plan_visible?(plan, turn:) && !backup.superseded?
      return false unless reviewed_reminders_authorized?(option, turn:)
      allowed = sources_authorized?(backup.source_context, profile_id: plan.relationship_profile_id, turn:, plan:, locale: backup.locale)
      return false unless allowed
      Context.verify!(turn:)
      return false if check_origin && !TaskSources.option_current?(option, turn:)
      return true unless backup.generated?

      selected = backup.source_context.map { |source| source["id"].to_s }
      current = ::EventPlans::ContextBuilder.new(event_plan: plan, locale: backup.locale,
        private_note_ids: selected.grep(/\Aprivate_note:/).map { |id| id.delete_prefix("private_note:") },
        vault_item_ids: selected.grep(/\Avault:/).map { |id| id.delete_prefix("vault:") },
        task_filter: ->(task) { TaskSources.input_visible?(task, turn:) }).call
      current.fingerprint == backup.context_fingerprint
    rescue Error, ActiveRecord::RecordNotFound
      false
    end

    def self.reviewed_reminders_authorized?(option, turn:)
      plan = option.backup_plan.event_plan
      profile = plan.relationship_profile
      ids = option.reviewed_reminders.pluck("id").uniq
      scope = if profile.professional?
        profile.work_context.selected("reminders")
      else
        turn.conversation.user.reminders
      end
      scope.where(event_plan_id: plan.id, id: ids).count == ids.size
    end

    def self.plan_visible?(plan, turn:)
      return false unless plan && turn && plan.user_id == turn.conversation.user_id && !plan.archived?
      profile = plan.relationship_profile
      return false unless profile.user_id == turn.conversation.user_id && !profile.archived?
      !profile.professional? || profile.work_context.selected("event_plans").exists?(id: plan.id)
    end

    def self.touch_visible?(item, turn:)
      return false unless item && turn
      checklist = item.personal_touch_checklist
      profile = checklist.relationship_profile
      return false unless profile.user_id == turn.conversation.user_id && !profile.archived? && !item.dismissed?
      return false if checklist.event_plan && !plan_visible?(checklist.event_plan, turn:)
      return true unless profile.professional?
      return false if checklist.important_date && !profile.work_context.selected("important_dates").exists?(id: checklist.important_date_id)
      return false if item.gift? && !profile.professional_gifts_allowed?

      item.source_context.all? do |source|
        association = Sources::ASSOCIATIONS[source["source_type"]]
        association && Sources.scope(profile:, association:, turn:).exists?(id: source["source_id"])
      end
    end
  end
end
