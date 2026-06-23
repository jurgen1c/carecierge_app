FerrumPdf.configure do |config|
  config.window_size = [ 1280, 800 ]
  config.browser_path = ENV["CHROME_PATH"] if ENV["CHROME_PATH"].present?
end
