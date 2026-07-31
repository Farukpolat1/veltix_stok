namespace :catalog do
  desc "Polat Pencere'nin gerçek Fiyat Teklifi belgelerindeki (Legend/Zendow Antrasit Gri seri) ürün kategorilerini ve ürünlerini ekler"
  task seed_polat_products: :environment do
    # Kategoriler idempotent (find_or_initialize + update) — Category stok
    # taşımaz, tekrar çalıştırmak güvenli. Var olan seeds.rb'deki taksonomiyle
    # aynı desen (name/code/product_type/color/brand/accessory_type).
    categories = [
      { name: "Legend Sürme Kasa Profili", code: "PRF-LEGEND-KASA-ANT", product_type: :profil, color: "Antrasit Gri", brand: "Egepen" },
      { name: "Legend Sürme Ortakayıt Profili", code: "PRF-LEGEND-ORTAKAYIT-ANT", product_type: :profil, color: "Antrasit Gri", brand: "Egepen" },
      { name: "Legend Sürme Plus Kanat Profili", code: "PRF-LEGEND-KANAT-ANT", product_type: :profil, color: "Antrasit Gri", brand: "Egepen" },
      { name: "Zendow Kasa Profili", code: "PRF-ZENDOW-KASA-ANT", product_type: :profil, color: "Antrasit Gri", brand: "Egepen" },
      { name: "Zendow Ortakayıt Profili", code: "PRF-ZENDOW-ORTAKAYIT-ANT", product_type: :profil, color: "Antrasit Gri", brand: "Egepen" },
      { name: "Zendow Kanat Profili", code: "PRF-ZENDOW-KANAT-ANT", product_type: :profil, color: "Antrasit Gri", brand: "Egepen" },
      { name: "Sabit Sürme Kasa Profili", code: "PRF-SABITSURME-KASA-ANT", product_type: :profil, color: "Antrasit Gri", brand: "Egepen" },
      { name: "Sürme Dikey Ortakayıt Profili", code: "PRF-SURME-DIKEYORTAKAYIT-ANT", product_type: :profil, color: "Antrasit Gri", brand: "Egepen" },
      { name: "Sürme Kanat Profili", code: "PRF-SURME-KANAT-ANT", product_type: :profil, color: "Antrasit Gri", brand: "Egepen" },
      { name: "LS Plus Aksesuar", code: "AKS-LSPLUS", product_type: :aksesuar, accessory_type: "Diğer Aksesuar", brand: "Egepen" },
      { name: "Alttan Kilit Aksesuarı", code: "AKS-ALTTANKILIT", product_type: :aksesuar, accessory_type: "Kilitleme Bileşenleri (Karşılık/Kilit Göbeği)", brand: "Vorne" },
      { name: "Vasistas Çarpma Aksesuarı", code: "AKS-VASISTAS-CARPMA", product_type: :aksesuar, accessory_type: "Kanat Aksesuarları (Makas/Köşe Aparatı)" },
      { name: "Sürme Aksesuarı", code: "AKS-SURME", product_type: :aksesuar, accessory_type: "Diğer Aksesuar" },
      { name: "Nakliye ve Hizmet Bedelleri", code: "DGR-NAKLIYE", product_type: :diger }
    ]

    categories.each do |attrs|
      category = Category.find_or_initialize_by(name: attrs[:name])
      category.update!(attrs)
    end

    # Ürünler find_or_create_by! ile — tekrar çalıştırılırsa var olan stok
    # miktarına dokunulmaz, sadece eksik ürünler eklenir.
    products = [
      { name: "Leg.Sürme Kasa Ant.Gri Çift Lm.", category: "Legend Sürme Kasa Profili", unit: :mtul },
      { name: "Leg.Sürme Ortakayıt Ant.Gri Çift Lm.", category: "Legend Sürme Ortakayıt Profili", unit: :mtul },
      { name: "Leg.Sürme Plus Kanat H Ant.Gri Çift Lm.", category: "Legend Sürme Plus Kanat Profili", unit: :mtul },
      { name: "Zendow Kasa L-41 Ant.Gri Çift Lm.", category: "Zendow Kasa Profili", unit: :mtul },
      { name: "Zendow O.Kayıt T-40 Ant.Gri Çift Lm.", category: "Zendow Ortakayıt Profili", unit: :mtul },
      { name: "Zendow Kanat Z-58 Ant.Gri Çift Lm.", category: "Zendow Kanat Profili", unit: :mtul },
      { name: "Sabit Sürme Kasa Ant.Gri Çift Lm.", category: "Sabit Sürme Kasa Profili", unit: :mtul },
      { name: "Sürme Dikey Ortakayıt Ant.Gri Çift Lm.", category: "Sürme Dikey Ortakayıt Profili", unit: :mtul },
      { name: "Sürme Kanat Ant.Gri Çift Lm.", category: "Sürme Kanat Profili", unit: :mtul },
      { name: "Egepen LS Plus Aksesuar", category: "LS Plus Aksesuar", unit: :adet },
      { name: "Vorne Ç.A. Alttan Klt. 0-1640 Renkli", category: "Alttan Kilit Aksesuarı", unit: :adet },
      { name: "Vasistas Çarpma Aksesuar Renkli", category: "Vasistas Çarpma Aksesuarı", unit: :adet },
      { name: "Sürme Aksesuarı 1400><2000 Renkli", category: "Sürme Aksesuarı", unit: :adet },
      { name: "4+16+4 Çift Cam Konfor", category: "Cam", unit: :m2 },
      { name: "4+16+4 Çift Cam", category: "Cam", unit: :m2 },
      { name: "4+16+4 Çift Cam %20'den Küçük", category: "Cam", unit: :m2 },
      { name: "Nakliye Bedeli", category: "Nakliye ve Hizmet Bedelleri", unit: :adet }
    ]

    created = 0
    products.each do |attrs|
      category = Category.find_by!(name: attrs[:category])
      product = Product.find_or_create_by!(name: attrs[:name]) do |p|
        p.category = category
        p.unit = attrs[:unit]
        p.stock_quantity = 0
        p.min_stock_level = 0
      end
      created += 1 if product.previously_new_record?
    end

    puts "Tamamlandı: #{categories.size} kategori, #{products.size} ürün kontrol edildi (#{created} yeni ürün oluşturuldu). Stok miktarları 0 olarak başlatıldı — gerçek sayıları Mal Kabul ya da Stok Sayımı ile girin."
  end
end
