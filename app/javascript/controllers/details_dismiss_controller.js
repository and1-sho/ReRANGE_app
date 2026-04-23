import { Controller } from "@hotwired/stimulus"

// <details> メニューを外クリック・Esc で閉じる（標準の再トグルに頼らない）
export default class extends Controller {
  connect() {
    this._onDocClick = this._onDocClick.bind(this)
    this._onDocKeydown = this._onDocKeydown.bind(this)
    // capture: フィードカードのクリックで詳細へ飛ぶ処理より先に閉じる
    document.addEventListener("click", this._onDocClick, true)
    document.addEventListener("keydown", this._onDocKeydown)
  }

  disconnect() {
    document.removeEventListener("click", this._onDocClick, true)
    document.removeEventListener("keydown", this._onDocKeydown)
  }

  close() {
    this.element.removeAttribute("open")
  }

  _onDocClick(event) {
    if (!this.element.hasAttribute("open")) return
    if (this.element.contains(event.target)) return

    this.close()
    // 同じカード／記事内のクリックで閉じた直後に「詳細へ」等のバブル処理が走らないようにする
    const host = this.element.closest("article")
    if (host && host.contains(event.target)) {
      event.stopPropagation()
    }
  }

  _onDocKeydown(event) {
    if (event.key !== "Escape") return
    if (!this.element.hasAttribute("open")) return

    this.close()
  }
}
