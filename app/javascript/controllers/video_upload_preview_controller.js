import { Controller } from "@hotwired/stimulus"

// 動画ファイル選択後にブラウザ内でプレビュー（アップロード前）
export default class extends Controller {
  static targets = ["input", "player", "box"]

  connect() {
    this._url = null
  }

  disconnect() {
    this.revoke()
  }

  preview() {
    this.revoke()
    const file = this.inputTarget.files && this.inputTarget.files[0]

    if (!file || !file.type.startsWith("video/")) {
      this.boxTarget.hidden = true
      this.playerTarget.removeAttribute("src")
      return
    }

    this._url = URL.createObjectURL(file)
    this.playerTarget.src = this._url
    this.boxTarget.hidden = false
  }

  revoke() {
    if (this._url) {
      URL.revokeObjectURL(this._url)
      this._url = null
    }
  }
}
