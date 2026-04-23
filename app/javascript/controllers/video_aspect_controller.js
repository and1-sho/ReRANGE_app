import { Controller } from "@hotwired/stimulus"

// メタデータで横縦を判定し、横は 16:9 枠に cover、縦は contain（左右余白）
export default class extends Controller {
  static targets = ["video"]

  connect() {
    this._onLoaded = () => this.layout()
    const v = this.videoTarget
    v.addEventListener("loadedmetadata", this._onLoaded)
    if (v.readyState >= 1) {
      this.layout()
    }
  }

  disconnect() {
    this.videoTarget.removeEventListener("loadedmetadata", this._onLoaded)
  }

  layout() {
    const el = this.videoTarget
    const w = el.videoWidth
    const h = el.videoHeight
    if (!w || !h) return

    const root = this.element
    const landscape = w >= h
    root.classList.toggle("video-aspect--landscape", landscape)
    root.classList.toggle("video-aspect--portrait", !landscape)
  }
}
