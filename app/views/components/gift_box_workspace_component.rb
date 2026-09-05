class GiftBoxWorkspaceComponent < ApplicationViewComponent
  option :gift_box
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


  def workspace_path
    if gift_box.persisted?
      relationship_profile_gift_box_path(gift_box.relationship_profile, gift_box)
    else
      relationship_profile_gift_boxes_path(gift_box.relationship_profile)
    end
  end

  def form_items
    saved = gift_box.items.to_a
    saved + Array.new(saved.length < 30 ? 1 : 0) { gift_box.items.build }
  end

  def suggestions = GiftBoxes::Companions.new(gift_box).call
  def money(value) = value.is_a?(BigDecimal) ? value.to_s("F") : value
end
