import { Controller } from "@hotwired/stimulus"

// アカウントメニューを外側クリックや Esc で閉じる
export default class extends Controller {
  connect() {
    this.handleDocumentClick = this.handleDocumentClick.bind(this)
    this.handleDocumentKeydown = this.handleDocumentKeydown.bind(this)
    document.addEventListener("click", this.handleDocumentClick)
    document.addEventListener("keydown", this.handleDocumentKeydown)
  }

  disconnect() {
    document.removeEventListener("click", this.handleDocumentClick)
    document.removeEventListener("keydown", this.handleDocumentKeydown)
  }

  onSummaryClick() {
    // details の開閉自体はブラウザ標準に任せる
  }

  close() {
    this.element.removeAttribute("open")
  }

  handleDocumentClick(event) {
    if (!this.element.hasAttribute("open")) return
    if (this.element.contains(event.target)) return

    this.close()
  }

  handleDocumentKeydown(event) {
    if (event.key !== "Escape") return
    this.close()
  }
}
