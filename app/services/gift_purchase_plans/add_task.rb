module GiftPurchasePlans
  class AddTask
    def self.call(gift:, event_plan:, locale: I18n.locale)
      gift.relationship_profile.user.with_lock do
        gift.relationship_profile.with_lock do
          event_plan.with_lock do
            raise ActiveRecord::RecordNotFound unless gift.relationship_profile.kept? && event_plan.active? &&
              event_plan.relationship_profile_id == gift.relationship_profile_id &&
              event_plan.user_id == gift.relationship_profile.user_id

            plan = gift.reload.purchase_plan || raise(ActiveRecord::RecordNotFound)
            plan.with_lock do
              return plan.plan_task if plan.plan_task

              title = I18n.with_locale(locale) { I18n.t("gift_purchase_plans.task_title", name: gift.name) }
              task = event_plan.plan_tasks.create!(
                title: title.truncate(PlanTask::MAX_TITLE_LENGTH), due_on: plan.purchase_by,
                phase: "arrange", kind: "gift_idea", origin: "manual", source_context: [],
                position: (event_plan.plan_tasks.maximum(:position) || -1) + 1
              )
              plan.update!(plan_task: task)
              event_plan.increment!(:generation_version)
              task
            end
          end
        end
      end
    end
  end
end
