import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.onScroll = this.toggleShadow.bind(this)

    window.addEventListener("scroll", this.onScroll)

    this.toggleShadow()
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
  }

  toggleShadow() {
    if (window.scrollY > 20) {
      this.element.classList.add("is-scrolled")
    } else {
      this.element.classList.remove("is-scrolled")
    }
  }
}