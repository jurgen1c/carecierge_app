require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module CareciergeApp
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    config.active_record.generate_secure_token_on = :initialize
    component_view_path = "app/views/components"
    config.paths.add component_view_path, autoload: true, eager_load: true

    config.i18n.default_locale = :en
    config.i18n.available_locales = [ :es, :en ]

    config.x.mail_from = ENV.fetch("CARECIERGE_MAIL_FROM", "from@example.com")

    if config.respond_to?(:factory_bot)
      config.factory_bot.definition_file_paths = [ Rails.root.join("spec/factories") ]
    end

    config.generators do |generate|
      generate.orm :active_record, primary_key_type: :uuid
      generate.test_framework :rspec, fixture: true
      generate.fixture_replacement :factory_bot, dir: "spec/factories"
      generate.factory_bot dir: "spec/factories", suffix: "factory"
      generate.system_tests = nil
    end

    config.view_component.tap do |comp_config|
      comp_config.generate.sidecar = true
      comp_config.generate.preview_path = "spec/components/previews"
      comp_config.generate.preview = true
      comp_config.view_component_path = component_view_path
      comp_config.generate.path = component_view_path
      comp_config.generate.parent_class = "ApplicationViewComponent"
      comp_config.generate.use_component_path_for_rspec_tests = true
      comp_config.previews.paths = [ Rails.root.join("spec/components/previews").to_s ]
    end
  end
end
