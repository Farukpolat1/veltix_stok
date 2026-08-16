require "csv"

namespace :catalog do
  # db/data/categories_export.csv ve products_export.csv, yerel geliştirme
  # ortamında oluşturulan gerçek Egepen Deceuninck kataloğunun (46+ kategori,
  # 1100+ ürün) dışa aktarılmış hali — bkz. bu görevin nasıl üretildiği için
  # commit geçmişi. Production'da bu veri hiç yoktu (tüm içe aktarmalar bu
  # ana kadar sadece yerel veritabanına yapılmıştı), bu görev onu taşır.
  desc "Gerçek ürün kataloğunu (kategoriler + ürünler) CSV'den içeri aktarır — isme göre eşleşir, tekrar çalıştırmak güvenlidir"
  task import_full_catalog: :environment do
    company_name = ENV.fetch("COMPANY_NAME", "POLAT PENCERE A.Ş.")
    company = Company.find_or_create_by!(name: company_name)

    ActsAsTenant.with_tenant(company) do
      # Her deploy'da (bkz. bin/docker-entrypoint) otomatik çalıştırılıyor —
      # Render'ın ücretsiz planında Shell/One-Off Jobs olmadığı için tek
      # güvenilir yol bu. Katalog zaten yüklenmişse (1000+ ürün) her CSV
      # satırını tekrar tekrar işlemek soğuk başlangıcı yavaşlatmasın diye
      # erken çıkılıyor.
      if Product.count >= 1000
        puts "catalog:import_full_catalog — zaten yüklü (#{Product.count} ürün), atlanıyor."
        next
      end

      created_categories = 0
      updated_categories = 0
      CSV.foreach(Rails.root.join("db/data/categories_export.csv"), headers: true) do |row|
        category = Category.find_or_initialize_by(name: row["name"])
        was_new = category.new_record?
        category.code = row["code"].presence
        category.product_type = row["product_type"]
        category.color = row["color"].presence
        category.accessory_type = row["accessory_type"].presence
        category.brand = row["brand"].presence
        category.series = row["series"].presence
        category.dashboard_group = row["dashboard_group"].presence
        category.save!
        was_new ? created_categories += 1 : updated_categories += 1
      end
      puts "Kategoriler: #{created_categories} yeni, #{updated_categories} güncellendi."

      created_products = 0
      updated_products = 0
      skipped = []
      CSV.foreach(Rails.root.join("db/data/products_export.csv"), headers: true) do |row|
        category = Category.find_by(name: row["category_name"])
        unless category
          skipped << row["name"]
          next
        end

        product = Product.find_or_initialize_by(code: row["code"].presence || row["name"])
        was_new = product.new_record?
        product.name = row["name"]
        product.category = category
        product.unit = row["unit"]
        product.color = row["color"].presence
        product.aliases_text = row["aliases_text"]
        product.min_stock_level = row["min_stock_level"].presence || 0
        product.stock_quantity ||= 0
        product.save!
        was_new ? created_products += 1 : updated_products += 1
      end
      puts "Ürünler: #{created_products} yeni, #{updated_products} güncellendi."
      puts "Atlanan (kategorisi bulunamadı): #{skipped.join(', ')}" if skipped.any?
    end
  end
end
