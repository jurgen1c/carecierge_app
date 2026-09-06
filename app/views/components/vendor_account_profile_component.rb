class VendorAccountProfileComponent < ApplicationViewComponent
  option :account
  option :editable, default: -> { false }

  FIELDS = { business_name: 200, service_area: 200, offerings: 2_000, contact_channels: 950,
    source_url: 2_000, provenance: 950 }.freeze

  style :input do
    base { %w[mt-2 min-h-11 w-full rounded-lg border border-private-line bg-canvas px-3 py-2 text-base text-ink focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary] }
  end

  style :button do
    base { %w[inline-flex min-h-11 items-center justify-center rounded-lg bg-primary px-5 py-3 font-semibold text-canvas hover:bg-primary-hover focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary] }
  end
end
