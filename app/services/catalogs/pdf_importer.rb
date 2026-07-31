require "base64"

module Catalogs
  # Tedarikçi katalog/fiyat listesi PDF'ini Gemini API ile okuyup Kategori ve
  # Ürün kayıtlarını otomatik oluşturur — daha önce elle (ör. Egepen Legend/
  # Zendow seri listesi için) yapılan kategori+ürün girişinin otomatikleşmiş
  # hali. Alış/Satış PDF okuyuculardan farklı olarak bir fatura/sipariş
  # oluşturmaz, sadece ürün kataloğunu (stok sıfır olarak) genişletir —
  # gerçek stok miktarları bilinmediği için uydurulmaz, Mal Kabul/Stok
  # Sayımı ile ayrıca girilmelidir.
  class PdfImporter
    class ParseError < StandardError; end

    UNIT_ALIASES = {
      "mtül" => "mtul", "mtul" => "mtul", "metretül" => "mtul", "mt" => "mt", "metre" => "mt",
      "adet" => "adet", "koli" => "koli", "kutu" => "kutu", "paket" => "paket",
      "m²" => "m2", "m2" => "m2"
    }.freeze

    EXTRACTION_TOOL = {
      name: "extract_catalog",
      description: "PDF katalog/fiyat listesinden çıkarılan kategori ve ürünleri kaydeder.",
      input_schema: {
        type: "object",
        properties: {
          items: {
            type: "array",
            description: "Belgedeki her bir ürün/kalem",
            items: {
              type: "object",
              properties: {
                category_name: { type: "string", description: "Bu ürünün ait olduğu kategori adı (ör. \"Zendow Kasa Profili\") — aynı seriden/parçadan ürünler aynı kategori adını paylaşmalı" },
                product_name: { type: "string", description: "Ürünün tam adı (ör. \"Zendow Kasa L-41 Ant.Gri Çift Lm.\")" },
                unit: { type: "string", description: "Birim: mtül, adet, m² gibi" },
                product_type: { type: "string", description: "profil, aksesuar ya da diger — hangisi olduğuna karar ver" },
                series: { type: "string", description: "profil/aksesuar ise hangi seriye ait (ör. 70 Serisi, 80 Serisi, Sürme Seri), bilinmiyorsa boş bırak" },
                color: { type: "string", description: "profil ise renk (Egepen kartelasından, ör. Beyaz, Antrasit Gri), değilse boş bırak" },
                brand: { type: "string", description: "Marka (Egepen, Vorne, Accado, Diğer), bilinmiyorsa boş bırak" },
                accessory_type: { type: "string", description: "aksesuar ise alt tür, değilse boş bırak" }
              },
              required: [ "category_name", "product_name", "unit", "product_type" ]
            }
          }
        },
        required: [ "items" ]
      }
    }.freeze

    attr_reader :created_categories, :created_products

    def initialize(pdf_binary)
      @pdf_binary = pdf_binary
      @created_categories = []
      @created_products = []
    end

    def call
      data = extract_with_gemini
      items = Array(data[:items])
      raise ParseError, "Belgede ürün bulunamadı." if items.empty?

      Category.transaction do
        items.each { |item| build_item(item) }
      end

      { categories: @created_categories, products: @created_products }
    end

    private
      def extract_with_gemini
        Gemini::DocumentExtractor.call(
          pdf_binary: @pdf_binary,
          prompt: "Bu, bir PVC/pencere/donanım tedarikçisinin ürün kataloğu ya da fiyat listesidir. " \
                  "Listedeki her ürünü çıkar: hangi kategoriye (seri/parça grubuna) ait olduğu, tam adı, birimi " \
                  "(mtül/adet/m² gibi), tipi (profil/aksesuar/diğer), profil ise rengi " \
                  "(#{color_options.join(', ')} listesinden birine en yakın olanı seç), " \
                  "markası (#{brand_options.join(', ')} listesinden), aksesuar ise alt türü " \
                  "(#{accessory_type_options.join(', ')} listesinden en yakın olanı seç), " \
                  "profil/aksesuar ise hangi seriye ait olduğu (#{series_options.join(', ')} listesinden en yakın olanı seç, " \
                  "belgede 70lik/80lik/sürme gibi bir ayrım varsa buna göre belirle). " \
                  "Aynı seriden/parçadan ürünleri aynı kategori adı altında grupla.",
          tool_name: EXTRACTION_TOOL[:name],
          tool_description: EXTRACTION_TOOL[:description],
          input_schema: EXTRACTION_TOOL[:input_schema]
        )
      rescue Gemini::DocumentExtractor::ExtractionError => e
        raise ParseError, e.message
      end

      def build_item(item_data)
        item_data ||= {}
        category_name = item_data[:category_name].to_s.strip
        product_name = item_data[:product_name].to_s.strip
        raise ParseError, "Bir kalemde kategori ya da ürün adı bulunamadı." if category_name.blank? || product_name.blank?

        category = find_or_update_category(category_name, item_data)
        product = Product.find_by("lower(name) = ?", product_name.downcase)

        if product.nil?
          unit = UNIT_ALIASES[item_data[:unit].to_s.strip.downcase]
          product = Product.create!(name: product_name, category: category, unit: unit, stock_quantity: 0, min_stock_level: 0)
          @created_products << product.name
        end
      end

      def find_or_update_category(name, item_data)
        product_type = item_data[:product_type].to_s.strip.downcase
        product_type = "diger" unless Category.product_types.key?(product_type)

        category = Category.find_or_initialize_by(name: name)
        was_new = category.new_record?

        category.product_type = product_type
        if product_type == "profil"
          color = item_data[:color].to_s.strip.presence
          category.color = color_options.find { |c| c.casecmp?(color) } || color || category.color.presence || "Beyaz"
        end
        if product_type == "aksesuar"
          accessory_type = item_data[:accessory_type].to_s.strip.presence
          category.accessory_type = accessory_type_options.find { |t| t.casecmp?(accessory_type) } || accessory_type || category.accessory_type.presence || "Diğer Aksesuar"
        end
        if product_type == "profil" || product_type == "aksesuar"
          series = item_data[:series].to_s.strip.presence
          category.series = series_options.find { |s| s.casecmp?(series) } || series || category.series
        end
        brand = item_data[:brand].to_s.strip.presence
        category.brand = brand_options.find { |b| b.casecmp?(brand) } || brand || category.brand

        category.save!
        @created_categories << category.name if was_new
        category
      end

      def color_options = @color_options ||= Category.color_options
      def accessory_type_options = @accessory_type_options ||= Category.accessory_type_options
      def brand_options = @brand_options ||= Category.brand_options
      def series_options = @series_options ||= Category.series_options
  end
end
