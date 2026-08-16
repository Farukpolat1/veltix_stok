class EnablePgTrgmAndIndexProductsName < ActiveRecord::Migration[8.1]
  def change
    # Alış ve satış belgelerinde aynı ürün farklı isimle geçebiliyor (ör. alışta
    # "12551-BEYAZ Ege Lambri 200 (Beyaz)", satışta "Kapı Lambrisi") — tam isim
    # eşleşmesi (Product#aliases) bunu daha önce kaydedilmiş isimler için çözüyordu.
    # pg_trgm, PDF önizleme ekranında "bu isim hiçbir ürünle tam eşleşmiyor, ama
    # şuna benziyor" önerisi sunabilmek için gerekiyor (bkz. Product.suggest_matches).
    enable_extension "pg_trgm"

    add_index :products, :name, using: :gin, opclass: :gin_trgm_ops, name: "index_products_on_name_trigram"
  end
end
