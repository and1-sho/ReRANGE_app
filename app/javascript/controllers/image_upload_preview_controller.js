import { Controller } from "@hotwired/stimulus"

// プロフィール編集など: 画像のドラッグ＆ドロップ／クリック選択とブラウザ内プレビュー
export default class extends Controller {
  static targets = ["input", "dropzone", "preview", "thumb"]

  connect() {
    this._url = null
  }

  disconnect() {
    this.revoke()
  }

  openFilePicker() {
    if (!this.hasDropzoneTarget) return
    this.inputTarget.click()
  }

  onDragOver(event) {
    if (!this.hasDropzoneTarget) return
    event.preventDefault()
    event.stopPropagation()
    this.dropzoneTarget.classList.add("is-dragover")
  }

  onDragLeave(event) {
    if (!this.hasDropzoneTarget) return
    const next = event.relatedTarget
    if (next && this.dropzoneTarget.contains(next)) return
    this.dropzoneTarget.classList.remove("is-dragover")
  }

  onDrop(event) {
    if (!this.hasDropzoneTarget) return
    event.preventDefault()
    event.stopPropagation()
    this.dropzoneTarget.classList.remove("is-dragover")

    const file = event.dataTransfer?.files?.[0]
    if (!file || !file.type.startsWith("image/")) return

    const dt = new DataTransfer()
    dt.items.add(file)
    this.inputTarget.files = dt.files
    this.preview()
  }

  onDropzoneKeydown(event) {
    if (!this.hasDropzoneTarget) return
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault()
      this.openFilePicker()
    }
  }

  preview() {
    this.revoke()
    const file = this.inputTarget.files && this.inputTarget.files[0]

    if (!file || !file.type.startsWith("image/")) {
      if (this.hasPreviewTarget) this.previewTarget.hidden = true
      if (this.hasThumbTarget) this.thumbTarget.removeAttribute("src")
      return
    }

    this._url = URL.createObjectURL(file)
    if (this.hasThumbTarget) {
      this.thumbTarget.src = this._url
    }
    if (this.hasPreviewTarget) {
      this.previewTarget.hidden = false
    }
  }

  revoke() {
    if (this._url) {
      URL.revokeObjectURL(this._url)
      this._url = null
    }
  }
}
