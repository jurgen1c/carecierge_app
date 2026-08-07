import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["panel", "row", "selectedCapability"]
  static values = { selected: String }

  select(event) {
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return

    event.preventDefault()
    const capability = event.params.capability

    this.selectedValue = capability
    this.selectedCapabilityTarget.value = capability

    this.rowTargets.forEach((row) => {
      const selected = row.dataset.capabilityRow === capability
      row.dataset.selected = selected.toString()
      row.querySelector("a")?.setAttribute("aria-current", selected ? "true" : "false")
    })

    this.panelTargets.forEach((panel) => {
      panel.hidden = panel.dataset.capabilityPanel !== capability
    })

    const panel = this.panelTargets.find((candidate) => candidate.dataset.capabilityPanel === capability)
    panel?.querySelector("[data-inspector-heading]")?.focus()
    const location = new window.URL(event.currentTarget.href)
    Turbo.session.history.replace(location, Turbo.session.restorationIdentifier)
    Turbo.session.view.lastRenderedLocation = location
  }
}
