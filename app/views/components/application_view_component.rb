class ApplicationViewComponent < ViewComponent::Base
  extend ::Dry::Initializer

  include StyleVariantsHelper
  include ApplicationHelper

  option :should_render, default: -> { true }

  def render?
    should_render
  end
end
