class AutomationCapabilityInspectorComponent < ApplicationViewComponent
  option :capability
  option :overrides
  option :relationship_profiles
  option :selected

  style do
    base { %w[min-w-0 rounded-xl border border-stone-200 bg-white] }
  end

  style :risk do
    base { %w[inline-flex rounded-md px-2 py-1 text-xs font-semibold] }
    variants do
      risk do
        low { %w[bg-emerald-50 text-emerald-900] }
        medium { %w[bg-amber-50 text-amber-900] }
        high { %w[bg-red-50 text-red-900] }
      end
    end
    defaults { { risk: :low } }
  end

  def available_relationship_profiles
    overridden_ids = overrides.to_h { |override| [ override.relationship_profile_id, true ] }
    relationship_profiles.reject { |profile| overridden_ids.key?(profile.id) }
  end

  def capability_name
    t("automation_permissions.capabilities.#{capability.key}.name")
  end

  def capability_description
    t("automation_permissions.capabilities.#{capability.key}.description")
  end
end
