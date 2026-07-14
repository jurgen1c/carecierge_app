class ReminderEmailNotifier < Noticed::Event
  deliver_by :email do |config|
    config.mailer = "ReminderMailer"
    config.method = :due
  end

  validates :record, presence: true
end
