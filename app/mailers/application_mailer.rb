class ApplicationMailer < ActionMailer::Base
  default from: -> { Rails.application.config.x.mail_from }
  layout "mailer"
end
