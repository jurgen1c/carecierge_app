class SharedReminderNotifier < Noticed::Event
  validates :record, presence: true

  notification_methods do
    def message
      I18n.t("shared_spaces.notification")
    end

    def url
      record ? shared_relationship_space_path(record.shared_relationship_space_id) : shared_relationship_spaces_path
    end
  end
end
