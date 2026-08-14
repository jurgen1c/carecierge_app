Rails.application.config.after_initialize do
  attributes = ActionText::ContentHelper.allowed_attributes ||
    Class.new.include(ActionText::ContentHelper).new.sanitizer_allowed_attributes
  ActionText::ContentHelper.allowed_attributes = attributes | %w[loading decoding]
end
