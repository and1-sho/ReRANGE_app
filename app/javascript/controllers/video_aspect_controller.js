import { Controller } from "@hotwired/stimulus"

// メタデータから横・縦を判定し、16:9 または 9:16 の枠で object-fit: contain 表示にする
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
