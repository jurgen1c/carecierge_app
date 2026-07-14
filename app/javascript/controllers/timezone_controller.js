import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "scheduledAt"]
  static values = { capture: Boolean }

  connect() {
    if (!this.captureValue) return

    const timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone

    if (timeZone) this.inputTarget.value = timeZone
    if (!this.scheduledAtTarget.value) this.scheduledAtTarget.value = this.tomorrowAtCurrentHour()
  }

  tomorrowAtCurrentHour() {
    const tomorrow = new Date()
    tomorrow.setDate(tomorrow.getDate() + 1)
    tomorrow.setMinutes(0, 0, 0)

    const pad = (value) => String(value).padStart(2, "0")
    return `${tomorrow.getFullYear()}-${pad(tomorrow.getMonth() + 1)}-${pad(tomorrow.getDate())}T${pad(tomorrow.getHours())}:00`
  }
}
