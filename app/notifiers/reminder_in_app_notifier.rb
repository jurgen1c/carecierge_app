class ReminderInAppNotifier < Noticed::Event
  validates :record, presence: true

  notification_methods do
    def message
      I18n.t("notifiers.reminder_in_app.message", title: record.title)
    end

    def url
      reminders_path(relationship_profile_id: record.active_relationship_profile_id)
    end
  end
end
