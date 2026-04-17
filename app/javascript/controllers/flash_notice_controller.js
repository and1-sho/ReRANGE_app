import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.timeoutId = window.setTimeout(() => {
      this.element.classList.add("flash-message--hide")
      window.setTimeout(() => this.element.remove(), 250)
    }, 3500)
  }

  disconnect() {
    if (this.timeoutId) window.clearTimeout(this.timeoutId)
  }
}
