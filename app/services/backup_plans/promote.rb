module BackupPlans
  class Promote
    def self.call(actor:, backup_option:, vault_lease: nil, at: Time.current)
      new(actor:, backup_option:, vault_lease:, at:).call
    end

    def initialize(actor:, backup_option:, vault_lease:, at:)
      @actor = actor
      @backup_option = backup_option
      @vault_lease = vault_lease
      @at = at
    end

    def call
      promotion_error = nil
      result = actor.with_lock do
        relationship_profile.with_lock do
          event_plan.with_lock do
            backup_plan.lock!
            backup_option.lock!
            validate_owner!
            return backup_option if already_promoted?

            begin
              validate_available!
              replacement_tasks = lock_replacement_tasks!
              reminders = lock_replacement_reminders!(replacement_tasks)
              validate_current_context!
              validate_reviewed_reminders!(reminders)
            rescue PromotionUnavailableError => error
              promotion_error = error
              next
            end

            retire_and_detach_reminders!(reminders)
            replacement_tasks.each { |task| task.update!(superseded_at: at) }
            created_tasks = create_backup_tasks!
            preserve_plan_sources!(created_tasks)
            backup_option.update!(promoted_at: at)
            backup_plan.update!(status: "promoted", promoted_at: at)
            event_plan.increment!(:generation_version)
            record_audit!(created_tasks:, replacement_tasks:)
            backup_option
          end
        end
      end
      raise promotion_error if promotion_error

      result
    end

    private

    attr_reader :actor, :backup_option, :vault_lease, :at

    def backup_plan = backup_option.backup_plan
    def event_plan = backup_plan.event_plan
    def relationship_profile = event_plan.relationship_profile

    def validate_owner!
      return if backup_plan.user_id == actor.id && event_plan.user_id == actor.id && relationship_profile.user_id == actor.id

      raise ActiveRecord::RecordNotFound
    end

    def already_promoted?
      backup_plan.promoted? && backup_option.promoted_at.present?
    end

    def validate_available!
      valid = relationship_profile.kept? && event_plan.active? && backup_plan.generated? && backup_option.promoted_at.nil? &&
        backup_plan.event_plan_generation_version == event_plan.generation_version
      raise PromotionUnavailableError, "The event plan changed after these backup options were generated" unless valid
    end

    def validate_current_context!
      private_note_ids = selected_private_note_ids
      vault_item_ids = selected_vault_item_ids

      if vault_item_ids.any? && !vault_lease&.active_for?(actor)
        raise PromotionUnavailableError, "Privacy vault access is required"
      end

      selected_categories = []
      selected_categories << "private_notes" if private_note_ids.any?
      selected_categories << "vault" if vault_item_ids.any?
      record_sensitive_access(selected_categories)

      context = EventPlans::ContextBuilder.new(
        event_plan:,
        private_note_ids:,
        vault_item_ids:,
        locale: backup_plan.locale
      ).call
      return if context.fingerprint == backup_plan.context_fingerprint

      raise PromotionUnavailableError, "The authorized context changed after these backup options were generated"
    end

    def selected_private_note_ids
      selected_source_record_ids("private_note:")
    end

    def selected_vault_item_ids
      selected_source_record_ids("vault:")
    end

    def selected_source_record_ids(prefix)
      backup_plan.source_context.filter_map do |source|
        source_id = source["id"].to_s
        source_id.delete_prefix(prefix) if source_id.start_with?(prefix)
      end
    end

    def lock_replacement_tasks!
      ids = backup_option.replacement_task_ids.uniq
      booking_task_ids = Booking.where.not(plan_task_id: nil).select(:plan_task_id)
      tasks = event_plan.plan_tasks.current.incomplete.where.not(id: booking_task_ids).where(id: ids).reorder(:id).lock.to_a
      raise PromotionUnavailableError, "A replaced plan task is no longer available" unless tasks.map(&:id).sort == ids.sort

      tasks
    end

    def lock_replacement_reminders!(tasks)
      Reminder.active.where(plan_task: tasks).reorder(:id).lock.to_a
    end

    def validate_reviewed_reminders!(reminders)
      current = reminders.select(&:active?).map { |reminder| BackupOption.reminder_snapshot(reminder) }
      return if canonical_reminder_snapshots(current) == canonical_reminder_snapshots(backup_option.reviewed_reminders)

      raise PromotionUnavailableError, "A reminder changed after this backup option was reviewed"
    end

    def canonical_reminder_snapshots(snapshots)
      snapshots.sort_by { |snapshot| snapshot.fetch("id") }
    end

    def retire_and_detach_reminders!(reminders)
      reminders.each do |reminder|
        attributes = { plan_task: nil }
        if reminder.active?
          attributes.merge!(status: "completed", completed_at: at, snoozed_until: nil, next_delivery_at: nil)
        end
        reminder.update!(attributes)
      end
    end

    def record_sensitive_access(categories)
      return if (categories & %w[private_notes vault]).empty?

      AuditEvent.record!(
        user: actor,
        actor:,
        action: "sensitive_record.accessed",
        target: relationship_profile,
        metadata: { result: "event_plan_backup_promotion" }
      )
      return unless categories.include?("vault")

      VaultAccessEvent.record_safely(event_type: "viewed", user: actor, relationship_profile:)
    end

    def create_backup_tasks!
      next_position = event_plan.plan_tasks.maximum(:position).to_i + 1
      backup_option.task_blueprints.map.with_index do |blueprint, offset|
        event_plan.plan_tasks.create!(
          phase: blueprint.fetch("phase"),
          kind: blueprint.fetch("kind"),
          title: blueprint.fetch("title"),
          details: blueprint["details"],
          due_on: blueprint["due_on"],
          origin: "ai",
          source_context: blueprint.fetch("source_context"),
          position: next_position + offset,
          backup_option:
        )
      end
    end

    def preserve_plan_sources!(tasks)
      sources = (event_plan.source_context + tasks.flat_map(&:source_context)).uniq { |source| source["id"] }
      event_plan.update!(source_context: sources.first(EventPlan::MAX_SOURCES))
    end

    def record_audit!(created_tasks:, replacement_tasks:)
      AuditEvent.record!(
        user: actor,
        actor:,
        action: "event_plan.backup_option_promoted",
        target: event_plan,
        metadata: {
          result: "promoted",
          created_count: created_tasks.length,
          superseded_count: replacement_tasks.length
        }
      )
    end
  end
end
