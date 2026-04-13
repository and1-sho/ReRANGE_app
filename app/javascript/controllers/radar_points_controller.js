import { Controller } from "@hotwired/stimulus"

// レーダー6軸の合計を監視し、残りポイントを表示する
export default class extends Controller {
  static targets = ["input", "remaining"]

  connect() {
    this.update()
  }

  update() {
    const total = this.inputTargets.reduce((sum, element) => {
      const value = parseInt(element.value || "0", 10)
      return sum + (Number.isNaN(value) ? 0 : value)
    }, 0)

    const remaining = 20 - total
    this.remainingTarget.textContent = `${remaining}`
    this.remainingTarget.style.color = remaining < 0 ? "#b91c1c" : "#021b15"
  }
}
