import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["disclosure", "trigger"]

  closeOutside(event) {
    if (!this.disclosureTarget.contains(event.target)) this.close()
  }

  close(event) {
    if (event?.type === "keydown" && event.key !== "Escape") return
    if (!this.disclosureTarget.open) return
    this.disclosureTarget.open = false
    if (event?.type === "keydown") this.triggerTarget.focus()
  }
}
