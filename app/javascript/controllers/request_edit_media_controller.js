import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["removeInput", "videoWrap"]

  remove(event) {
    if (event) event.preventDefault()
    if (this.hasRemoveInputTarget) {
      this.removeInputTarget.checked = true
      this.removeInputTarget.dispatchEvent(new Event("change", { bubbles: true }))
    }
    if (this.hasVideoWrapTarget) {
      this.videoWrapTarget.hidden = true
      this.videoWrapTarget.classList.add("is-media-removed")
      this.videoWrapTarget.style.display = "none"
    }
  }
}
