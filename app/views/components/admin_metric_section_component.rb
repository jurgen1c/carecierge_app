class AdminMetricSectionComponent < ApplicationViewComponent
  option :section
  option :metrics

  style do
    base { %w[border-t border-private-line py-6] }
  end

  def display_value(value)
    return I18n.t("admin.dashboard.show.no_waiting") if value.nil?
    return I18n.l(value.to_date, format: :audit_event_day) if value.respond_to?(:to_date)

    helpers.number_with_delimiter(value)
  end
end
