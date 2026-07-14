require "rails_helper"

RSpec.describe "Production mailer configuration" do
  it "requires HTTPS links, a real sender, and an explicit SMTP transport" do
    configuration = Rails.root.join("config/environments/production.rb").read
    dockerfile = Rails.root.join("Dockerfile").read
    kamal_secrets = Rails.root.join(".kamal/secrets").read
    application_mailer = Rails.root.join("app/mailers/application_mailer.rb").read
    application_configuration = Rails.root.join("config/application.rb").read

    expect(configuration).to include('ENV["CARECIERGE_HOST"].presence')
    expect(configuration).to include('protocol: "https"')
    expect(configuration).to include("config.action_mailer.delivery_method = :smtp")
    expect(configuration).to include("config.action_mailer.raise_delivery_errors = true")
    expect(configuration).to include('smtp_value.call(:address, "CARECIERGE_SMTP_ADDRESS")')
    expect(configuration).to include('smtp_value.call(:from, "CARECIERGE_MAIL_FROM")')
    expect(configuration).to include('Integer(ENV.fetch("CARECIERGE_SMTP_PORT"')
    expect(configuration).to include(".to_sym")
    expect(configuration).to include("Unsupported SMTP authentication")
    expect(configuration).to include("Rails.application.credentials.smtp")
    expect(application_mailer).to include("Rails.application.config.x.mail_from")
    expect(application_configuration).to include("if config.respond_to?(:factory_bot)")
    expect(configuration).not_to include('default_url_options = { host: "example.com" }')
    expect(configuration).to include('from: "assets@invalid.test"')
    expect(configuration).to include('asset_build = ENV["SECRET_KEY_BASE_DUMMY"].present?')
    expect(configuration).to include('smtp_credentials = asset_build ? {} : Rails.application.credentials.smtp || {}')
    expect(dockerfile).to include("SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile")
    expect(kamal_secrets).to include('CARECIERGE_HOST=$CARECIERGE_HOST')
    expect(kamal_secrets).to include('CARECIERGE_MAIL_FROM=$CARECIERGE_MAIL_FROM')
    expect(kamal_secrets).to include('CARECIERGE_SMTP_PASSWORD=$CARECIERGE_SMTP_PASSWORD')
    expect(kamal_secrets).to include('CARECIERGE_SMTP_PORT=$CARECIERGE_SMTP_PORT')
    expect(kamal_secrets).to include('CARECIERGE_SMTP_AUTHENTICATION=$CARECIERGE_SMTP_AUTHENTICATION')
  end
end
