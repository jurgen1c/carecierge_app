class AutomationPermissionOverrideComponent < ApplicationViewComponent
  option :permission

  delegate :relationship_profile, to: :permission

  style do
    base { %w[group rounded-lg border border-stone-200 bg-white] }
  end

  style :summary do
    base do
      %w[
        flex min-h-11 cursor-pointer list-none items-center justify-between gap-3 rounded-lg px-3 py-2
        hover:bg-stone-50 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2
        focus-visible:outline-emerald-700
      ]
    end
  end

  def capability
    permission.capability_definition
  end
end
