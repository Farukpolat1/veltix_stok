class MakeProductionsProductRequired < ActiveRecord::Migration[8.1]
  def change
    # Reçete temelli eski üretim akışından kalma NULL product_id'li bir kayıt
    # sayfayı çökertiyordu (production.product.name -> nil hatası). Artık
    # üretim her zaman bir ürünle oluşturuluyor, bunu DB seviyesinde zorunlu kıl.
    change_column_null :productions, :product_id, false
  end
end
