class ChangeCategoriesProductTypeDefault < ActiveRecord::Migration[8.1]
  def change
    # Çeşit üçe indirildi (profil/aksesuar/diğer) — eski "diğer" değeri 5'ti, artık 2.
    change_column_default :categories, :product_type, from: 5, to: 2
  end
end
