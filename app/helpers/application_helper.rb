module ApplicationHelper
  # This method provides some syntactic sugar for rendering components
  # @example <%= component "example", title: "Hello World!" %> will render Example::Component.new(title: "Hello World!")
  # @example <%= component "way_down/we_go/example", title: "Hello World!" %> will render WayDown::WeGo::Example::Component
  # @param [String] name
  # @param [Array] args
  # @param [Hash] kwargs
  # @param [Block] block
  # @return [Component] rendered component
  def component(name, *, **, &)
    component = name.to_s.split("/").map(&:camelize).tap { |names| names[-1] += "Component" }.join("::").constantize
    render(component.new(*, **), &)
  end

  def disable_turbo_cache
    content_for :head, tag.meta(name: "turbo-cache-control", content: "no-cache")
  end
end
