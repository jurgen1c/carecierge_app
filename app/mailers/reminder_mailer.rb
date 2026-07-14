class ReminderMailer < ApplicationMailer
  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.reminder_mailer.due.subject
  #
  def due
    @reminder = params.fetch(:record)
    @recipient = params.fetch(:recipient)

    mail to: @recipient.email, subject: I18n.t("reminder_mailer.due.subject", title: @reminder.title)
  end
end
