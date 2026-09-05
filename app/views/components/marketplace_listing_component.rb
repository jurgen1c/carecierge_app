class MarketplaceListingComponent < ApplicationViewComponent
  option :listing
  option :heading, default: -> { true }

  style :link do
    base { %w[inline-flex min-h-11 items-center text-sm font-semibold text-primary underline underline-offset-4 focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary] }
  end
end
