require "semantic_logger"

SemanticLogger.application = Rails.application.class.module_parent_name
SemanticLogger.environment = Rails.env
SemanticLogger.default_level = ENV.fetch("RAILS_LOG_LEVEL", Rails.env.production? ? "info" : "debug").to_sym

unless SemanticLogger.appenders.any?
  appender_options = if Rails.env.production?
    { io: $stdout, formatter: :json }
  else
    { file_name: Rails.root.join("log", "#{Rails.env}.log").to_s, formatter: :default }
  end

  SemanticLogger.add_appender(**appender_options)
end

Rails.logger = ActiveSupport::TaggedLogging.new(SemanticLogger["Rails"])
Rails.application.config.logger = Rails.logger
