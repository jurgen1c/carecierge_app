require "rails_helper"
require "rails/command"
require "rails/commands/server/server_command"

RSpec.describe "Semantic logger server compatibility" do
  it "attaches console output during server startup and preserves tagged logging" do
    logger = Rails.logger
    server = Rails::Server.new
    allow(server).to receive(:wrapped_app)

    expect { server.send(:log_to_stdout) }.not_to raise_error

    console = logger.broadcasts.last
    expect(ActiveSupport::Logger.logger_outputs_to?(logger, STDOUT)).to be(true)
    expect(logger.broadcasts.first).to be_a(SemanticLogger::Logger)
    expect(Rails.application.config.logger).to equal(logger)

    output = StringIO.new
    sink = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(output))
    logger.broadcast_to(sink)
    logger.tagged("startup-check") { logger.info("console logging works") }
    expect(output.string).to include("[startup-check] console logging works")
  ensure
    logger.stop_broadcasting_to(console) if console
    logger.stop_broadcasting_to(sink) if sink
  end
end
