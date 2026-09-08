class WorkspacePreview < ViewComponent::Preview
  def person
    render PersonIdentityComponent.new(name: "María Elena", subtitle: "Friend", size: :large)
  end

  def date
    render DateMarkerComponent.new(date: Date.new(2026, 9, 12))
  end

  def action
    render ActionLinkComponent.new(label: "Add someone", path: "/relationship_profiles/new", variant: :primary, icon: :people)
  end

  def section
    render ProfileSectionComponent.new(section: "plans", context: "Call María · September 12", expanded: true) do
      "Reminders and promises appear here when you open this section."
    end
  end
end
