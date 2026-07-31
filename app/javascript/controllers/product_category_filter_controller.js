import { Controller } from "@hotwired/stimulus"

// Satış/fatura satırı eklerken "Ürün Adı" alanının önerdiği listeyi (datalist)
// kategori checkbox'larına göre daraltır — yüzlerce ürün arasında doğru
// kategoriyi işaretleyip aramayı hızlandırmak için. Hiçbir kutu işaretli
// değilse tüm ürünler önerilir.
export default class extends Controller {
  static targets = ["checkbox", "datalist"]
  static values = { products: Array }

  connect() {
    this.applyFilter()
  }

  applyFilter() {
    const checkedIds = this.checkboxTargets.filter((box) => box.checked).map((box) => box.dataset.categoryId)
    const visible = checkedIds.length === 0
      ? this.productsValue
      : this.productsValue.filter((product) => checkedIds.includes(String(product.categoryId)))

    this.datalistTarget.replaceChildren(
      ...visible.map((product) => {
        const option = document.createElement("option")
        option.value = product.name
        return option
      })
    )
  }
}
