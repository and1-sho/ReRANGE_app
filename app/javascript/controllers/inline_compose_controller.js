import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field", "actions", "videoInput", "preview", "previewVideo", "duration", "removeToggle"]

  connect() {
    this.previewUrl = null
    if (this._hasText()) this._expand()
    if (this.hasPreviewTarget && !this.previewTarget.hidden) this._expand()
  }

  expand() {
    this._expand()
  }

  cancel() {
    this.fieldTarget.value = ""
    this._clearMedia()
    this.element.classList.remove("is-expanded")
    this.actionsTarget.hidden = true
    this.fieldTarget.blur()
  }

  onInput() {
    if (this._hasText()) {
      this._expand()
    } else {
      this.actionsTarget.hidden = true
    }
  }

  onMediaChange() {
    if (!this.hasVideoInputTarget || this.videoInputTarget.files.length === 0) {
      this._clearMedia()
      return
    }

    const [file] = this.videoInputTarget.files
    if (this.hasRemoveToggleTarget) this.removeToggleTarget.checked = false
    this._revokePreviewUrl()
    this.previewUrl = URL.createObjectURL(file)
    if (this.hasPreviewVideoTarget) {
      this.previewVideoTarget.src = this.previewUrl
      this.previewVideoTarget.load()
    }
    if (this.hasPreviewTarget) this.previewTarget.hidden = false
    this._expand()
  }

  removeMedia() {
    this._clearMedia()
    if (this.hasRemoveToggleTarget) this.removeToggleTarget.checked = true
  }

  captureDuration() {
    if (this.hasDurationTarget && this.hasPreviewVideoTarget) {
      this.durationTarget.textContent = this._formatDuration(this.previewVideoTarget.duration)
    }
  }

  _expand() {
    this.element.classList.add("is-expanded")
    this.actionsTarget.hidden = false
  }

  _hasText() {
    return this.fieldTarget.value.trim().length > 0
  }

  _clearMedia() {
    if (this.hasVideoInputTarget) this.videoInputTarget.value = ""
    if (this.hasPreviewVideoTarget) {
      this.previewVideoTarget.removeAttribute("src")
      this.previewVideoTarget.load()
    }
    if (this.hasDurationTarget) this.durationTarget.textContent = ""
    if (this.hasPreviewTarget) this.previewTarget.hidden = true
    this._revokePreviewUrl()
  }

  _revokePreviewUrl() {
    if (!this.previewUrl) return

    URL.revokeObjectURL(this.previewUrl)
    this.previewUrl = null
  }

  _formatDuration(durationInSeconds) {
    const total = Math.max(0, Math.floor(durationInSeconds || 0))
    const hours = Math.floor(total / 3600)
    const minutes = Math.floor((total % 3600) / 60)
    const seconds = total % 60
    if (hours > 0) return `${hours}:${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`

    return `${minutes}:${String(seconds).padStart(2, "0")}`
  }
}
