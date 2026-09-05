class GiftPurchaseWorkspaceComponent < ApplicationViewComponent
  option :gift
  option :purchase_plan
  option :event_plans

  style :control do
    base { %w[mt-2 min-h-11 w-full rounded-lg border border-stone-300 bg-canvas px-3 py-2 text-base text-ink focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20] }
  end
  style :button do
    base { %w[inline-flex min-h-11 items-center justify-center rounded-lg px-4 py-3 text-sm font-semibold focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary] }
    variants do
      emphasis do
        primary { %w[bg-primary text-canvas hover:bg-primary-hover] }
        secondary { %w[border border-private-line bg-canvas text-primary hover:bg-surface] }
      end
    end
    defaults { { emphasis: :secondary } }
  end

  def workspace_path = relationship_profile_gift_purchase_plan_path(gift.relationship_profile, gift)
  def displayed_options
    options = purchase_plan.options.is_a?(Array) ? purchase_plan.options.select { |option| option.is_a?(Hash) } : []
    Array.new(GiftPurchasePlan::MAX_OPTIONS) { |index| options[index] || {} }
  end

  def money(value)
    return if value.nil?

    value.is_a?(BigDecimal) ? value.to_s("F") : value
  end
end
