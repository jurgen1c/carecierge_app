class DigestInAppNotifier < Noticed::Event
  validates :record, presence: true

  notification_methods do
    def message
      snapshot = params[:digest_snapshot] || params["digest_snapshot"]
      actions = Array(snapshot&.with_indifferent_access&.fetch(:items, nil)).map do |raw_item|
        item = raw_item.with_indifferent_access
        if item.fetch(:kind) == "check_in"
          I18n.t("digests.items.check_in_title", name: item.fetch(:relationship_name))
        elsif item.fetch(:kind).in?([ "upcoming_date", "planning_prompt" ]) && item[:title].blank?
          I18n.t("important_dates.date_types.#{item.fetch(:date_type)}")
        else
          item.fetch(:title)
        end
      end.join("; ")
      actions = I18n.t("digest_mailer.summary.all_actions") if actions.blank?
      I18n.t(
        "notifiers.digest_in_app.message",
        mode: I18n.t("notification_preferences.digest_modes.#{params[:mode]}"),
        actions:
      )
    end

    def url
      reminders_path
    end
  end
end
