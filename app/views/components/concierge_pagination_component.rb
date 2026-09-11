class ConciergePaginationComponent < ApplicationViewComponent
  option :pagination
  option :kind

  style :container do
    base { %w[concierge-pagination] }
  end

  style :link do
    base { %w[workspace-action workspace-action-secondary] }
  end

  def render?
    pagination.last > 1
  end

  def page_path(number)
    helpers.concierge_page_path(**{ "#{kind}_page".to_sym => number })
  end
end
