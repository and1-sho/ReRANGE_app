import { Controller } from "@hotwired/stimulus"

// 一覧の動画サムネ: 縦長画像は pillarbox（contain）、横長はこれまでどおり cover
export default class extends Controller {
  static targets = ["image"]

  connect() {
    if (this.hasImageTarget && this.imageTarget.complete && this.imageTarget.naturalWidth) {
      this.applyLayout(this.imageTarget)
    }
  }

  onLoad(event) {
    this.applyLayout(event.currentTarget)
  }

  applyLayout(img) {
    if (!img.naturalWidth || !img.naturalHeight) return

    if (img.naturalHeight > img.naturalWidth) {
      this.element.classList.add("request-card__thumb-wrap--portrait")
    } else {
      this.element.classList.remove("request-card__thumb-wrap--portrait")
    }
  }
}
