import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["form", "input", "send", "transcript", "status", "history", "recovery"]
  static values = { url: String, page: String }

  connect() {
    if (this.hasHistoryTarget && window.matchMedia("(min-width: 65rem)").matches) this.historyTarget.open = true
    this.following = true
    if (this.hasTranscriptTarget) this.transcriptTarget.scrollTop = this.transcriptTarget.scrollHeight
    this.pollStartedAt = Date.now()
    this.failures = 0
    this.schedule()
  }

  disconnect() {
    window.clearTimeout(this.timer)
    window.clearTimeout(this.requestTimeout)
    this.request?.abort()
  }

  transcriptTargetConnected() {
    if (this.following) this.transcriptTarget.scrollTop = this.transcriptTarget.scrollHeight
    else if (this.readingOffset !== undefined) this.transcriptTarget.scrollTop = this.readingOffset
    if (this.transcriptFocused) {
      const control = this.focusedControlKey && this.transcriptTarget.querySelector(`[data-concierge-focus-key="${window.CSS.escape(this.focusedControlKey)}"]`)
      const focusTarget = control || this.transcriptTarget
      focusTarget.focus({ preventScroll: true })
    }
    this.transcriptFocused = false
    if (this.hasSendTarget) this.sendTarget.disabled = this.busy
    if (this.hasStatusTarget && this.lastAnnouncement !== this.transcriptTarget.dataset.announcement) {
      this.lastAnnouncement = this.transcriptTarget.dataset.announcement
      this.statusTarget.textContent = this.lastAnnouncement
    }
    this.schedule()
  }

  focusContextPage(event) {
    if (event.target !== event.currentTarget) return
    event.target.querySelector('input[type="checkbox"]')?.focus()
  }

  useStarter(event) {
    if (!this.hasInputTarget) return
    this.inputTarget.value = event.currentTarget.dataset.prompt
    this.inputTarget.focus()
    this.inputTarget.setSelectionRange(this.inputTarget.value.length, this.inputTarget.value.length)
  }

  submitWithKeyboard(event) {
    if (event.key !== "Enter" || event.shiftKey || event.isComposing) return
    event.preventDefault()
    if (!this.busy && this.formTarget.reportValidity()) this.formTarget.requestSubmit()
  }

  get busy() {
    return this.hasTranscriptTarget && this.transcriptTarget.dataset.busy === "true"
  }

  schedule() {
    window.clearTimeout(this.timer)
    if (this.failures >= 3 || Date.now() - this.pollStartedAt > 360000) {
      if (this.hasRecoveryTarget) this.recoveryTarget.hidden = false
      return
    }
    if (this.busy && this.hasUrlValue && this.urlValue) this.timer = window.setTimeout(() => this.refresh(), 1000)
  }

  resume() {
    this.failures = 0
    this.pollStartedAt = Date.now()
    if (this.hasRecoveryTarget) this.recoveryTarget.hidden = true
    this.refresh()
  }

  async refresh() {
    if (!this.element.isConnected || !this.busy) return
    this.request = new window.AbortController()
    this.requestTimeout = window.setTimeout(() => this.request.abort(), 10000)
    try {
      const response = await window.fetch(this.urlValue, {
        headers: { Accept: "text/vnd.turbo-stream.html" },
        credentials: "same-origin", cache: "no-store", signal: this.request.signal
      })
      if (response.redirected) {
        Turbo.visit(response.url)
        return
      }
      if (response.ok && response.headers.get("content-type")?.includes("turbo-stream")) {
        this.failures = 0
        const html = await response.text()
        this.readingOffset = this.transcriptTarget.scrollTop
        this.following = this.transcriptTarget.scrollHeight - this.readingOffset - this.transcriptTarget.clientHeight < 100
        this.transcriptFocused = this.transcriptTarget.contains(document.activeElement)
        this.focusedControlKey = document.activeElement?.dataset.conciergeFocusKey
        Turbo.renderStreamMessage(html)
      } else if (response.status === 401 || response.status === 403 || response.status === 404) {
        Turbo.visit(this.pageValue)
        return
      } else {
        this.failures += 1
      }
    } catch {
      if (!this.element.isConnected) return
      this.failures += 1
    } finally {
      window.clearTimeout(this.requestTimeout)
    }
    this.schedule()
  }
}
