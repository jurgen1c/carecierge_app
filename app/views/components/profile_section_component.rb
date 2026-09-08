class ProfileSectionComponent < ApplicationViewComponent
  option :section
  option :expanded, default: -> { false }
  option :context, optional: true

  style { base { %w[profile-section workspace-panel] } }

  def title
    t("profile_workspace.sections.#{section}.title")
  end

  def description
    t("profile_workspace.sections.#{section}.description")
  end
end
