module EventPlans
  class Create
    def self.call(user:, relationship_profile:, attributes:, locale: I18n.locale)
      EventPlan.transaction do
        user.with_lock do
          relationship_profile.with_lock do
            raise ActiveRecord::RecordNotFound if relationship_profile.discarded?

            plan = user.event_plans.create!(attributes.merge(relationship_profile:))
            Template.for(occasion_type: plan.occasion_type, starts_on: plan.starts_on, locale:).each do |task_attributes|
              plan.plan_tasks.create!(task_attributes)
            end
            plan
          end
        end
      end
    end
  end
end
