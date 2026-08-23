module EventPlans
  class Create
    def self.call(user:, relationship_profile:, attributes:, important_date_id: nil, locale: I18n.locale)
      EventPlan.transaction do
        user.with_lock do
          relationship_profile.with_lock do
            raise ActiveRecord::RecordNotFound if relationship_profile.discarded?

            birthday_source = birthday_source_context(
              relationship_profile:,
              important_date_id:,
              occasion_type: attributes[:occasion_type],
              locale:
            )
            plan = user.event_plans.create!(attributes.merge(birthday_source).merge(relationship_profile:))
            Template.for(occasion_type: plan.occasion_type, starts_on: plan.starts_on, locale:).each do |task_attributes|
              plan.plan_tasks.create!(task_attributes)
            end
            plan
          end
        end
      end
    end

    def self.birthday_source_context(relationship_profile:, important_date_id:, occasion_type:, locale:)
      return {} if important_date_id.blank?
      raise ActiveRecord::RecordNotFound unless occasion_type.to_s == "birthday"

      important_date = relationship_profile.important_dates.lock.find(important_date_id)
      raise ActiveRecord::RecordNotFound unless important_date.date_type == "birthday"

      {
        source_context: [
          {
            "id" => "important_date:#{important_date.id}",
            "label" => I18n.t("event_plans.sources.important_date", locale:),
            "role" => "birthday_origin"
          }
        ]
      }
    end
    private_class_method :birthday_source_context
  end
end
