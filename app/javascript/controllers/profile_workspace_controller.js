import { Controller } from "@hotwired/stimulus"

// Native disclosures still work without JavaScript. Enhancement preserves legacy
// fragment links and reveals form errors after Turbo replaces a frame.
export default class extends Controller {
  connect() {
    this.revealLocation()
    this.revealErrors()
  }

  revealLocation() {
    let id
    try {
      id = decodeURIComponent(window.location.hash.slice(1))
    } catch {
      return
    }
    if (!id) return
    const target = document.getElementById(id)
    if (!target || !this.element.contains(target)) return
    this.openAncestors(target)
    window.requestAnimationFrame(() => target.scrollIntoView({ block: "start" }))
  }

  revealErrors() {
    this.element.querySelectorAll('form [role="alert"], .field_with_errors').forEach(element => {
      this.openAncestors(element)
    })
  }

  revealFrame(event) {
    const frame = event.target
    this.openAncestors(frame)
    this.revealErrors()
    // Action-only refreshes should not move the viewport or steal the next click.
    const field = frame.querySelector('form input:not([type="hidden"]):not([disabled]), form select:not([disabled]), form textarea:not([disabled])')
    if (!field) return
    window.requestAnimationFrame(() => {
      if (!frame.isConnected) return
      frame.scrollIntoView({ block: "start" })
      field.focus({ preventScroll: true })
    })
  }

  openAncestors(element) {
    let current = element
    while (current && current !== this.element) {
      if (current.tagName === "DETAILS") current.open = true
      current = current.parentElement
    }
  }
}
