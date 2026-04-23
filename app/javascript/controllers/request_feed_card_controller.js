import { Controller } from "@hotwired/stimulus"

// フィードの1件: 枠は CSS の :hover。リンク・動画以外のクリックで詳細へ
export default class extends Controller {
  static values = { detailUrl: String }

  connect() {
    this._onClick = this._onClick.bind(this)
    this.element.addEventListener("click", this._onClick)
  }

  disconnect() {
    this.element.removeEventListener("click", this._onClick)
  }

  _onClick(event) {
    if (event.target.closest("a")) return
    if (event.target.closest("details")) return
    if (event.target.closest(".request-card__thumb-wrap")) return

    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return

    event.preventDefault()

    if (window.Turbo?.visit) {
      window.Turbo.visit(this.detailUrlValue)
    } else {
      window.location.assign(this.detailUrlValue)
    }
  }
}
