class EnablePgTrgmAndIndexProductsName < ActiveRecord::Migration[8.1]
  # Alış ve satış belgelerinde aynı ürün farklı isimle geçebiliyor (ör. alışta
  # "12551-BEYAZ Ege Lambri 200 (Beyaz)", satışta "Kapı Lambrisi") — tam isim
  # eşleşmesi (Product#aliases) bunu daha önce kaydedilmiş isimler için çözüyordu.
  # pg_trgm, PDF önizleme ekranında "bu isim hiçbir ürünle tam eşleşmiyor, ama
  # şuna benziyor" önerisi sunabilmek için gerekiyor (bkz. Product.suggest_matches).
  #
  # up/down (change değil) ve rescue ile sarmalı: bazı yönetilen Postgres
  # sağlayıcılarında (paylaşımlı/kısıtlı plan) uygulama kullanıcısının
  # CREATE EXTENSION izni olmayabilir — bu durumda tüm deploy'u (ve dolayısıyla
  # giriş ekranı dahil TÜM uygulamayı) durdurmak yerine, sadece bu öneri
  # özelliği devre dışı kalır (bkz. Product.suggest_matches'taki rescue).
  def up
    enable_extension "pg_trgm"
    add_index :products, :name, using: :gin, opclass: :gin_trgm_ops, name: "index_products_on_name_trigram"
  rescue ActiveRecord::StatementInvalid => e
    say "pg_trgm eklenemedi (izin sorunu olabilir), atlanıyor: #{e.message}", true
  end

  def down
    remove_index :products, name: "index_products_on_name_trigram", if_exists: true
    disable_extension "pg_trgm"
  rescue ActiveRecord::StatementInvalid
    nil
  end
end
