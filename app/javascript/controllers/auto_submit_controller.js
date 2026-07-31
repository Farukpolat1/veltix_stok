import { Controller } from "@hotwired/stimulus"

// Filtre formunu, kullanıcı yazmayı bitirdikten kısa bir süre sonra otomatik
// gönderir — "Ara" butonuna basmadan canlı filtreleme hissi verir. Tam sayfa
// yenilemesi arama kutusundaki odağı sıfırladığı için, hangi alanın
// odaklandığını sessionStorage'da saklayıp sayfa yeniden yüklendiğinde
// odağı ve imleç konumunu geri veririz.
const FOCUS_KEY = "auto-submit-focus-field"

export default class extends Controller {
  static values = { delay: { type: Number, default: 400 } }

  connect() {
    const fieldName = sessionStorage.getItem(FOCUS_KEY)
    if (!fieldName) return
    sessionStorage.removeItem(FOCUS_KEY)

    const field = this.element.querySelector(`[name="${fieldName}"]`)
    if (!field) return
    field.focus()
    const length = field.value.length
    field.setSelectionRange?.(length, length)
  }

  submit(event) {
    sessionStorage.setItem(FOCUS_KEY, event.target.name)
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.element.requestSubmit(), this.delayValue)
  }

  submitNow(event) {
    sessionStorage.setItem(FOCUS_KEY, event.target.name)
    clearTimeout(this.timeout)
    this.element.requestSubmit()
  }
}
