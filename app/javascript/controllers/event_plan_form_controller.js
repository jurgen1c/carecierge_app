import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["effort", "occasion", "prior", "priorSelect", "relationship"]

  initialize() {
    this.restorePriorOptions = this.restorePriorOptions.bind(this)
  }

  connect() {
    if (this.hasPriorSelectTarget) {
      this.priorOptions = Array.from(this.priorSelectTarget.options).map((option) => option.cloneNode(true))
      document.addEventListener("turbo:before-cache", this.restorePriorOptions)
    }

    this.refresh()
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this.restorePriorOptions)
  }

  refresh() {
    const anniversary = this.occasionTarget.value === "anniversary"
    this.effortTarget.hidden = !anniversary
    if (!this.hasPriorTarget) return

    const relationshipId = this.relationshipTarget.value
    const options = this.priorOptions.filter((option) => {
      return option.value === "" || option.dataset.relationshipProfileId === relationshipId
    }).map((option) => option.cloneNode(true))
    const selectedValue = this.priorSelectTarget.value
    this.priorSelectTarget.replaceChildren(...options)
    const available = anniversary && options.length > 1
    const selectionAvailable = options.some((option) => option.value === selectedValue)

    this.priorSelectTarget.value = available && selectionAvailable ? selectedValue : ""
    this.priorSelectTarget.disabled = !available
    this.priorTarget.hidden = !available
  }

  restorePriorOptions() {
    if (!this.hasPriorSelectTarget || !this.priorOptions) return

    const selectedValue = this.priorSelectTarget.value
    const options = this.priorOptions.map((option) => option.cloneNode(true))
    this.priorSelectTarget.replaceChildren(...options)
    if (options.some((option) => option.value === selectedValue)) {
      this.priorSelectTarget.value = selectedValue
    }
  }
}
