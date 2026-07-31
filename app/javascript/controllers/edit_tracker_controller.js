import { Controller } from "@hotwired/stimulus"

// PDF'ten okunan önizleme formunda kullanıcı bir alanı değiştirdiğinde
// yanına küçük bir "değiştirildi" rozeti gösterir — hangi alanların AI
// çıktısından farklı olduğu belli olsun diye.
export default class extends Controller {
  static targets = ["field", "badge"]

  connect() {
    this.fieldTargets.forEach((field) => {
      field.dataset.originalValue = field.value
    })
  }

  check(event) {
    const field = event.target
    const badge = field.closest("[data-edit-tracker-target='wrapper']")?.querySelector("[data-edit-tracker-target='badge']")
    if (!badge) return
    badge.classList.toggle("d-none", field.value === field.dataset.originalValue)
  }
}
