module EventPlans
  class Create
    def self.call(
      user:,
      relationship_profile:,
      attributes:,
      important_date_id: nil,
      prior_event_plan_id: nil,
      locale: I18n.locale
    )
      EventPlan.transaction do
        user.with_lock do
          relationship_profile.with_lock do
            raise ActiveRecord::RecordNotFound if relationship_profile.discarded?

            origin_sources = important_date_source_context(
              relationship_profile:,
              important_date_id:,
              occasion_type: attributes[:occasion_type],
              locale:
            )
            origin_sources.concat(prior_anniversary_source_context(
              relationship_profile:,
              prior_event_plan_id:,
              occasion_type: attributes[:occasion_type],
              locale:
            ))
            plan = user.event_plans.create!(attributes.merge(source_context: origin_sources, relationship_profile:))
            Template.for(
              occasion_type: plan.occasion_type,
              starts_on: plan.starts_on,
              tone: plan.tone,
              effort_level: plan.effort_level,
              locale:
            ).each do |task_attributes|
              plan.plan_tasks.create!(task_attributes)
            end
            plan
          end
        end
      end
    end

    def self.important_date_source_context(relationship_profile:, important_date_id:, occasion_type:, locale:)
      return [] if important_date_id.blank?

      important_date = relationship_profile.important_dates.lock.find(important_date_id)
      role = case occasion_type.to_s
      when "birthday"
        "birthday_origin" if important_date.date_type == "birthday"
      when "anniversary"
        "anniversary_origin" if important_date.date_type.in?(%w[anniversary milestone])
      end
      raise ActiveRecord::RecordNotFound unless role

      [
        {
          "id" => "important_date:#{important_date.id}",
          "label" => I18n.t("event_plans.sources.important_date", locale:),
          "role" => role,
          "date_type" => important_date.date_type
        }
      ]
    end

    def self.prior_anniversary_source_context(relationship_profile:, prior_event_plan_id:, occasion_type:, locale:)
      return [] if prior_event_plan_id.blank?
      return [] unless occasion_type.to_s == "anniversary"

      prior_plan = relationship_profile.event_plans.lock.find_by(
        id: prior_event_plan_id,
        occasion_type: "anniversary",
        status: %w[completed archived]
      )
      return [] unless prior_plan

      [
        {
          "id" => "event_plan:#{prior_plan.id}",
          "label" => I18n.t("event_plans.sources.prior_anniversary_plan", locale:),
          "role" => "prior_anniversary_context",
          "certainty" => "needs_confirmation"
        }
      ]
    end
    private_class_method :important_date_source_context, :prior_anniversary_source_context
  end
end
