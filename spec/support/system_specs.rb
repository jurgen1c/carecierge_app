require "capybara/cuprite"

Capybara.default_max_wait_time = 5
Capybara.javascript_driver = :cuprite
Capybara.save_path = Rails.root.join("tmp/capybara")
Capybara.server = :puma, { Silent: true }

Capybara.register_driver :cuprite do |app|
  Capybara::Cuprite::Driver.new(
    app,
    browser_options: { "no-sandbox" => nil },
    js_errors: true,
    process_timeout: 10,
    timeout: 10,
    window_size: [ 1280, 800 ]
  )
end

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :cuprite
  end
end
