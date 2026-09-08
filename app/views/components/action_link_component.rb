class ActionLinkComponent < ApplicationViewComponent
  option :label
  option :path
  option :variant, default: -> { :secondary }
  option :icon, optional: true
  option :turbo_frame, optional: true

  style do
    base { %w[workspace-action] }
    variants do
      variant do
        primary { %w[workspace-action-primary] }
        secondary { %w[workspace-action-secondary] }
        quiet { %w[workspace-action-quiet] }
      end
    end
  end
end
