import { Controller } from "@hotwired/stimulus"

// 新規リクエスト: 公開/非公開に応じてトレーナー選択の表示と disabled を切り替える
export default class extends Controller {
  static targets = ["trainerWrapper", "trainerSelect", "privateRadio"]

  connect() {
    this.sync()
  }

  sync() {
    const isPrivate = this.privateRadioTarget.checked
    if (isPrivate) {
      this.trainerWrapperTarget.classList.remove("request-compose__visibility-trainer--hidden")
      this.trainerSelectTarget.disabled = false
    } else {
      this.trainerWrapperTarget.classList.add("request-compose__visibility-trainer--hidden")
      this.trainerSelectTarget.disabled = true
      this.trainerSelectTarget.value = ""
    }
  }
}
