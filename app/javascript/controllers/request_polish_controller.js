import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "title",
    "body",
    "polishButton",
    "attempts",
    "error",
    "proposal",
    "proposalTitle",
    "proposalBody"
  ]

  static values = {
    endpoint: String,
    maxAttempts: Number,
    remainingAttempts: Number,
    draftToken: String,
    minBodyLength: Number
  }

  connect() {
    this.remainingAttempts = this.hasRemainingAttemptsValue ? this.remainingAttemptsValue : this.maxAttemptsValue
    this.isLoading = false
    this.proposalData = null
    this.renderAttempts()
    this.onBodyInput()
  }

  onBodyInput() {
    this.clearError()
    this.updatePolishButtonState()
  }

  async polish() {
    if (!this.canPolish()) return

    this.isLoading = true
    this.updatePolishButtonState()
    this.clearError()

    try {
      const response = await fetch(this.endpointValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        body: JSON.stringify({ body: this.bodyTarget.value, draft_token: this.draftTokenValue })
      })

      const payload = await this.parseResponse(response)
      if (!response.ok) {
        const error = new Error(payload.error || "文章の整形に失敗しました。")
        error.payload = payload
        throw error
      }

      this.proposalData = payload
      this.proposalTitleTarget.textContent = `タイトル案: ${payload.title}`
      this.proposalBodyTarget.textContent = payload.body
      this.proposalTarget.hidden = false
      this.syncRemainingAttempts(payload)
    } catch (error) {
      this.syncRemainingAttempts(error.payload)
      this.showError(error.message || "文章の整形に失敗しました。")
    } finally {
      this.isLoading = false
      this.updatePolishButtonState()
    }
  }

  adopt() {
    if (!this.proposalData) return

    this.titleTarget.value = this.proposalData.title
    this.bodyTarget.value = this.proposalData.body
    this.titleTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.bodyTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.proposalTarget.hidden = true
    this.onBodyInput()
  }

  canPolish() {
    return (
      !this.isLoading &&
      this.remainingAttempts > 0 &&
      this.bodyTarget.value.trim().length >= this.minBodyLengthValue
    )
  }

  updatePolishButtonState() {
    this.polishButtonTarget.disabled = !this.canPolish()
    this.polishButtonTarget.textContent = this.isLoading ? "整えています..." : "文章を整える"
  }

  renderAttempts() {
    this.attemptsTarget.textContent = this.remainingAttempts
  }

  showError(message) {
    this.errorTarget.textContent = message
    this.errorTarget.hidden = false
  }

  clearError() {
    this.errorTarget.textContent = ""
    this.errorTarget.hidden = true
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }

  async parseResponse(response) {
    const contentType = response.headers.get("content-type") || ""
    if (contentType.includes("application/json")) {
      return await response.json()
    }

    const text = await response.text()
    if (text.startsWith("<!DOCTYPE") || text.startsWith("<html")) {
      throw new Error("整形リクエストに失敗しました。再読み込み後にもう一度お試しください。")
    }

    return { error: "整形リクエストに失敗しました。" }
  }

  syncRemainingAttempts(payload) {
    if (!payload || typeof payload.remaining_attempts !== "number") return

    this.remainingAttempts = Math.max(payload.remaining_attempts, 0)
    this.renderAttempts()
  }
}
