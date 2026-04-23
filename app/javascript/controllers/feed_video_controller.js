import { Controller } from "@hotwired/stimulus"

// フィード: 画面内ではミュート自動再生、外れたら停止。横 cover / 縦 contain
export default class extends Controller {
  static targets = ["video"]

  connect() {
    this._onLoaded = () => this.layout()
    const v = this.videoTarget
    v.addEventListener("loadedmetadata", this._onLoaded)
    if (v.readyState >= 1) {
      this.layout()
    }

    if (!window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this._observer = new IntersectionObserver(
        (entries) => {
          entries.forEach((entry) => {
            if (entry.isIntersecting) {
              v.play().catch(() => {})
            } else {
              v.pause()
            }
          })
        },
        { root: null, rootMargin: "0px 0px -10% 0px", threshold: 0.2 }
      )
      this._observer.observe(this.element)
    }
  }

  disconnect() {
    this.videoTarget.removeEventListener("loadedmetadata", this._onLoaded)
    this._observer?.disconnect()
    this.videoTarget.pause()
  }

  layout() {
    const el = this.videoTarget
    const w = el.videoWidth
    const h = el.videoHeight
    if (!w || !h) return

    const portrait = h > w
    this.element.classList.toggle("request-card__thumb-wrap--portrait", portrait)
    this.element.classList.toggle("request-card__thumb-wrap--landscape", !portrait)
  }
}
