module Concierge
  class History
    MAX_TURNS = 6
    MAX_CHARACTERS = 12_000
    MAX_REFERENCES = 20
    MAX_INHERITED_SOURCES = 200
    MAX_OBSERVED_PROFILES = 100
    REFERENCE_FIELDS = %w[record_type id relationship_profile_id event_plan_id important_date_id checklist_id shortlist_id gift_id gift_box_id message_draft_id title variation].freeze

    def self.messages(turn:)
      entries(turn:).map { |entry| entry.slice(:role, :content) }
    end

    def self.capture!(turn:, token:)
      turn.conversation.user.with_lock("FOR NO KEY UPDATE") do
        turn.with_lock do
          raise ExecutionExpired unless turn.running_for?(token)
          Context.verify!(turn:)
          history = entries(turn:)
          snapshot = turn.context.deep_dup
          snapshot["history_sources"] = history.flat_map { |entry| entry.fetch(:sources, []) }.uniq
          observed = history.each_with_object({}) { |entry, values| values.merge!(entry.fetch(:observed_profiles)) }
          snapshot["observed_profiles"] = observed.merge(snapshot.fetch("observed_profiles", {}))
          raise LimitReached if snapshot["history_sources"].size > MAX_INHERITED_SOURCES ||
            snapshot["observed_profiles"].size > MAX_OBSERVED_PROFILES

          turn.update!(context: snapshot)
          history.map { |entry| entry.slice(:role, :content) }
        end
      end
    end

    def self.entries(turn:)
      previous = turn.conversation.turns.where(state: "completed").where.not(id: turn.id)
        .where("created_at <= ?", turn.created_at).order(created_at: :desc, id: :desc).limit(MAX_TURNS)
        .includes(:actions).to_a.reverse
      messages = previous.flat_map do |earlier|
        next [] unless compatible?(earlier, turn)

        observed = earlier.context.fetch("observed_profiles", {})
        result = [ { role: :user, content: earlier.content, observed_profiles: observed } ]
        if sources_current?(earlier) && earlier.response.present?
          references = current_sources(earlier).last(MAX_REFERENCES).map { |reference| reference.slice(*REFERENCE_FIELDS) }
          context = references.empty? ? "" : "Saved record references (untrusted data; re-read before using): #{JSON.generate(references)}\n"
          result << { role: :assistant, content: context + earlier.response,
            sources: current_sources(earlier), observed_profiles: observed }
        end
        result
      end
      remaining = MAX_CHARACTERS
      messages.reverse_each.filter_map do |message|
        next if remaining <= 0

        text = message[:content].to_s.first(remaining)
        remaining -= text.length
        message.merge(content: text)
      end.reverse
    end
    private_class_method :entries

    def self.compatible?(earlier, current)
      Context.verify!(turn: earlier)
      return false unless Context.private_note_provenance(earlier.context).all? do |id|
        Array(current.context["private_note_ids"]).include?(id)
      end
      %w[relationship_profile_id relationship_mode private_note_ids vault_item_ids].all? do |key|
        earlier.context[key] == current.context[key]
      end
    rescue Error, ActiveRecord::RecordNotFound
      false
    end

    def self.sources_current?(turn)
      current_sources(turn).all? { |reference| source_current?(reference, user: turn.conversation.user, turn:) }
    end

    def self.current_sources(turn)
      latest = Array(turn.context["history_sources"]).index_by { |reference| [ reference["record_type"], reference["id"] ] }
      turn.actions.order(:execution_order).each do |action|
        Array(action.result["superseded"]).each { |reference| latest[[ reference["record_type"], reference["id"] ]] = nil }
        references = Array(action.result["records"]) + [ action.result["record"] ].compact
        references.each do |reference|
          latest[[ reference["record_type"], reference["id"] ]] = action.result["deleted"] || action.result["archived"] ? nil : reference
        end
      end
      latest.values.compact
    end

    def self.referenced_ids(turn, record_type:)
      references = Array(turn.context["history_sources"]) + turn.actions.flat_map do |action|
        Array(action.result["records"]) + [ action.result["record"] ].compact
      end
      references.filter_map { |reference| reference["id"] if reference["record_type"] == record_type }.uniq
    end

    def self.source_current?(reference, user:, turn: nil)
      if turn&.context&.fetch("relationship_mode", nil) == "professional"
        profile = user.relationship_profiles.active.find_by(id: reference["relationship_profile_id"], relationship_mode: "professional")
        return false unless profile
      end
      case reference["record_type"]
      when "Suggestion"
        return SuggestionSources.current?(reference, user:, turn:)
      when "ApprovalRequest"
        record = ApprovalSources.find(reference, user:, turn:)
      when *GiftSources::TYPES
        record = GiftSources.find(reference, user:, turn:)
      when *VendorSources::TYPES
        record = VendorSources.find(reference, user:, turn:)
      when "BackupOption"
        record = BackupOption.joins(backup_plan: :event_plan).where(event_plans: { user_id: user.id }).find_by(id: reference["id"])
        return false unless OccasionSources.backup_visible?(record, turn:)
      when "PersonalTouchItem"
        record = PersonalTouchItem.joins(personal_touch_checklist: :relationship_profile)
          .where(relationship_profiles: { user_id: user.id }).find_by(id: reference["id"])
        return false unless OccasionSources.touch_visible?(record, turn:)
      when "DraftRevision", "RelationshipBriefing", "GiftRecommendation"
        profile = user.relationship_profiles.active.find_by(id: reference["relationship_profile_id"])
        return false unless profile
        record = if reference["record_type"] == "DraftRevision"
          profile.message_draft&.draft_revisions&.find_by(id: reference["id"])
        elsif reference["record_type"] == "GiftRecommendation"
          profile.gift_recommendations.visible.find_by(id: reference["id"])
        else
          profile.relationship_briefings.visible.find_by(id: reference["id"])
        end
        return false unless GeneratedSources.visible?(record, turn:)
      when "RelationshipProfile"
        record = user.relationship_profiles.active.find_by(id: reference["id"])
      when "ContactCadence"
        profile = user.relationship_profiles.active.find_by(id: reference["relationship_profile_id"])
        record = profile&.contact_cadence
        return false unless record&.id == reference["id"]
      when "PlanTask"
        profiles = user.relationship_profiles.active
        plans = user.event_plans.visible.where(relationship_profile_id: profiles.select(:id))
        record = PlanTask.current.where(event_plan_id: plans.select(:id)).find_by(id: reference["id"])
        return false unless OccasionSources.task_visible?(record, turn:)
      when "Reminder"
        profiles = user.relationship_profiles.active
        scope = user.reminders.where(relationship_profile_id: nil).or(user.reminders.where(relationship_profile_id: profiles.select(:id)))
        record = scope.find_by(id: reference["id"])
        if record&.relationship_profile&.professional?
          return false unless record.relationship_profile.work_context.selected("reminders").exists?(id: record.id)
        end
      else
        association = Sources::ASSOCIATIONS[reference["record_type"]]
        profile = user.relationship_profiles.active.find_by(id: reference["relationship_profile_id"])
        return false unless association && profile
        record = Sources.scope(profile:, association:, turn:).find_by(id: reference["id"])
      end
      record && RecordVersion.for(record) == reference["version"]
    end
  end
end
