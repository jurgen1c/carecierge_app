class AutomationCapabilityRowComponent < ApplicationViewComponent
  option :capability
  option :selected_mode
  option :selected
  option :override_count

  style do
    base do
      %w[
        grid gap-3 border-t border-stone-200 px-4 py-4 transition sm:px-5
        lg:grid-cols-[minmax(0,1fr)_7rem_minmax(21rem,1.25fr)] lg:items-center
        data-[selected=true]:bg-emerald-50/70
      ]
    end
  end

  style :risk do
    base { %w[inline-flex w-fit rounded-md px-2 py-1 text-xs font-semibold] }
    variants do
      risk do
        low { %w[bg-emerald-50 text-emerald-900] }
        medium { %w[bg-amber-50 text-amber-900] }
        high { %w[bg-red-50 text-red-900] }
      end
    end
    defaults { { risk: :low } }
  end

  def capability_name
    t("automation_permissions.capabilities.#{capability.key}.name")
  end

  def capability_description
    t("automation_permissions.capabilities.#{capability.key}.description")
  end
end
