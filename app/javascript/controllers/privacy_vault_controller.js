import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "locked"]
  static values = { leaseDuration: Number, lockKey: String }

  connect() {
    this.handleStorage = this.handleStorage.bind(this)
    window.addEventListener("storage", this.handleStorage)
    this.scheduleExpiry()
  }

  disconnect() {
    window.removeEventListener("storage", this.handleStorage)
    window.clearTimeout(this.expiryTimeout)
  }

  leaseDurationValueChanged() {
    this.scheduleExpiry()
  }

  lock() {
    try {
      window.localStorage.setItem(this.lockKeyValue, Date.now().toString())
    } catch {
      // The initiating tab must still conceal content when storage is unavailable.
    } finally {
      window.setTimeout(() => this.conceal(), 0)
    }
  }

  handleStorage(event) {
    if (event.key === this.lockKeyValue) this.conceal()
  }

  scheduleExpiry() {
    window.clearTimeout(this.expiryTimeout)
    if (!this.hasLeaseDurationValue) return

    if (this.leaseDurationValue <= 0) {
      this.conceal()
    } else {
      this.expiryTimeout = window.setTimeout(() => this.conceal(), this.leaseDurationValue)
    }
  }

  conceal() {
    window.clearTimeout(this.expiryTimeout)
    if (this.hasContentTarget) this.contentTarget.remove()
    if (this.hasLockedTarget) this.lockedTarget.hidden = false
  }
}
