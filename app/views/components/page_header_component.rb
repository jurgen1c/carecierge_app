class PageHeaderComponent < ApplicationViewComponent
  option :title
  option :description, optional: true
  option :context, optional: true
  option :heading_id, optional: true
  style { base { %w[workspace-header] } }
end
