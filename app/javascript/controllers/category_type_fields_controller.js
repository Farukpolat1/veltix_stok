import { Controller } from "@hotwired/stimulus"

// Kategori formunda seçilen Çeşide (Profil/Aksesuar/...) göre Renk ya da
// Alt Tür alanlarını gösterir/gizler ve gizliyken devre dışı bırakır ki
// ilgisiz bir değer yanlışlıkla kaydedilmesin.
export default class extends Controller {
  static targets = ["typeSelect", "profilFields", "aksesuarFields"]

  connect() {
    this.update()
  }

  update() {
    const type = this.typeSelectTarget.value
    this.toggle(this.profilFieldsTarget, type === "profil")
    this.toggle(this.aksesuarFieldsTarget, type === "aksesuar")
  }

  toggle(el, show) {
    el.classList.toggle("d-none", !show)
    el.querySelectorAll("select, input").forEach((field) => {
      field.disabled = !show
    })
  }
}
