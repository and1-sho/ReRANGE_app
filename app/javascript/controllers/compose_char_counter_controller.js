import { Controller } from "@hotwired/stimulus"

// 入力欄の「現在文字数 / 最大」の同期（タイトル・本文など）
export default class extends Controller {
  static targets = ["field", "count"]
  static values = { max: { type: Number, default: 24 } }

  connect() {
    this.sync()
  }

  sync() {
    const n = this.fieldTarget.value.length
    this.countTarget.textContent = String(n)
  }
}
