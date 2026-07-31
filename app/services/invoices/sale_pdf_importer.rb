require "base64"
require "bigdecimal"
require "bigdecimal/util"

module Invoices
  # Müşteriden gelen sipariş/ürün listesi PDF'ini Gemini API ile okur. İki
  # aşamalıdır: #extract sadece PDF'i okuyup ham veriyi döner (hiçbir şey
  # kaydetmez); kullanıcı bu veriyi bir önizleme ekranında gözden geçirip
  # düzeltebilir; onayladığında #persist gerçek Sale + SaleLine kayıtlarını
  # oluşturur. Satış satırları her zaman bir Product'a bağlanır (dış kaynaklı
  # ham veri kalmaz) — çünkü satılan şey zaten kendi stoğumuzdaki bir ürün;
  # Products::FindOrCreate ile isim eşleşirse mevcut ürün kullanılır, eşleşmezse
  # (kategori verilmemişse "Sınıflandırılmamış" altında) yeni ürün açılır.
  #
  # Şema, Polat Pencere'nin standart "FİYAT TEKLİFİ" belgesine göre kalibre
  # edildi (Cari Kodu/Cari Ünvanı üst bilgisi, Açıklama/Metraj/Birim/Birim
  # Tutar tablosu, alttaki "1.İskonto %" oranı) — bkz. örnek belgeler.
  class SalePdfImporter
    DEFAULT_VAT_RATE = 20

    UNIT_ALIASES = {
      "mtül" => "mtul", "mtul" => "mtul", "metretül" => "mtul", "mt" => "mt", "metre" => "mt",
      "adet" => "adet", "koli" => "koli", "kutu" => "kutu", "paket" => "paket",
      "m²" => "m2", "m2" => "m2"
    }.freeze

    EXTRACTION_TOOL = {
      name: "extract_sale_order",
      description: "PDF'ten çıkarılan fiyat teklifi/sipariş verisini kaydeder.",
      input_schema: {
        type: "object",
        properties: {
          sale_date: { type: "string", description: "Sipariş/Sevk Tarihi alanındaki ilk (sipariş) tarih, YYYY-MM-DD formatında." },
          order_number: { type: "string", description: "\"Sipariş No\" alanındaki değer, örn. 6060826. Belgede yoksa boş bırak." },
          discount_rate: { type: "number", description: "Belgedeki genel iskonto oranı, örn. \"1.İskonto % 8,00\" ise 8. Belirtilmemişse 0." },
          customer: {
            type: "object",
            properties: {
              code: { type: "string", description: "\"Cari Kodu\" alanındaki değer, örn. C3-00854. Belgede yoksa boş bırak." },
              name: { type: "string", description: "\"Cari Ünvanı\" alanındaki müşteri/firma adı" },
              tax_number: { type: "string", description: "Müşterinin VKN/TCKN numarası, belgede yoksa boş bırak" },
              tax_office: { type: "string", description: "Müşterinin vergi dairesi, belgede yoksa boş bırak" },
              address: { type: "string", description: "Müşterinin açık adresi (mahalle/sokak/ilçe/il dahil tek satır), belgede yoksa boş bırak" },
              phone: { type: "string", description: "Müşterinin telefonu, belgede yoksa boş bırak" }
            },
            required: [ "name" ]
          },
          lines: {
            type: "array",
            description: "Fiyat teklifi tablosundaki her poz/satır",
            items: {
              type: "object",
              properties: {
                code: { type: "string", description: "Ürün/stok kodu, belgede yoksa boş bırak" },
                name: { type: "string", description: "\"Açıklama\" sütunundaki kalem adı" },
                quantity: { type: "number", description: "\"Metraj\" sütunundaki miktar" },
                unit: { type: "string", description: "\"Birim\" sütunu: mtül, adet, m² gibi" },
                unit_price: { type: "number", description: "\"Birim Tutar\" sütunu — iskonto uygulanmamış liste fiyatı" },
                vat_rate: { type: "number", description: "KDV oranı (yüzde, örn. 20). Belirtilmemişse belgedeki genel KDV oranını kullan, o da yoksa 20." }
              },
              required: [ "name", "quantity" ]
            }
          }
        },
        required: [ "customer", "lines" ]
      }
    }.freeze

    class ParseError < StandardError; end

    attr_reader :newly_created_products

    def initialize(pdf_binary = nil, created_by: nil)
      @pdf_binary = pdf_binary
      @created_by = created_by
      @newly_created_products = []
    end

    # Faz 1 — sadece okur, hiçbir kayıt oluşturmaz. Dönen hash önizleme
    # formunda gösterilir; kullanıcı düzenleyip #persist'e geçirir.
    def extract
      extract_with_gemini
    end

    # Faz 2 — (muhtemelen kullanıcı tarafından düzenlenmiş) veriyi kaydeder.
    def persist(data)
      sale_date = parse_date(data[:sale_date]) || Date.current
      discount_rate = to_decimal(data[:discount_rate]) || 0
      lines = Array(data[:lines])
      raise ParseError, "Belgede ürün satırı bulunamadı." if lines.empty?

      Sale.transaction do
        customer = find_or_create_customer(data[:customer])

        sale = Sale.new(
          sale_date: sale_date,
          customer: customer,
          created_by: @created_by,
          external_order_number: data[:order_number].to_s.strip.presence
        )
        sale.save!

        lines.each { |line| build_line(sale, line, discount_rate) }

        sale
      end
    end

    # Geriye dönük uyumluluk / tek adımda okuyup kaydetmek isteyenler için.
    def call
      persist(extract)
    end

    # Zaten var olan bir satışa, PDF'ten okunan satırları ekler — müşteri/tarih
    # zaten belli olduğu için sadece ürün satırları işlenir (bkz. items sayfası
    # "PDF'ten Ürün Ekle").
    def persist_lines(sale, lines_data, discount_rate: 0)
      lines = Array(lines_data)
      raise ParseError, "Belgede ürün satırı bulunamadı." if lines.empty?

      rate = to_decimal(discount_rate) || 0
      Sale.transaction { lines.each { |line| build_line(sale, line, rate) } }
      sale
    end

    private
      def extract_with_gemini
        Gemini::DocumentExtractor.call(
          pdf_binary: @pdf_binary,
          prompt: "Bu, Polat Pencere'nin Egepen Deceuninck PVC pencere/kapı sistemleri için düzenlediği " \
                  "standart 'FİYAT TEKLİFİ' belgesidir. Üst bilgideki 'Cari Kodu' (örn. C3-00854) ve " \
                  "'Cari Ünvanı' değerlerini müşteri bilgisi olarak kullan. 'Sipariş No' alanındaki değeri " \
                  "sipariş numarası olarak çıkar. 'Sipariş / Sevk Tar' alanındaki " \
                  "ilk tarihi sipariş tarihi olarak al. Tablodaki her satır bir poz: 'Açıklama' ürün adı, " \
                  "'Metraj' miktar, 'Birim' (mtül/adet/m² gibi), 'Birim Tutar' iskontosuz birim fiyattır. " \
                  "Tablo altındaki '1.İskonto %' değerini genel iskonto oranı, 'KDV oranı %' değerini " \
                  "KDV oranı olarak çıkar.",
          tool_name: EXTRACTION_TOOL[:name],
          tool_description: EXTRACTION_TOOL[:description],
          input_schema: EXTRACTION_TOOL[:input_schema]
        )
      rescue Gemini::DocumentExtractor::ExtractionError => e
        raise ParseError, e.message
      end

      # Cari Kodu belgede varsa (Polat Pencere'nin kendi muhasebe kodu) önce onunla
      # eşleştirir — bu, daha önce içeri aktarılan cari listesindeki (Customer#code)
      # kayıtla birebir örtüşür. Yoksa VKN/TCKN'ye, o da yoksa isme düşer.
      def find_or_create_customer(customer_data)
        customer_data ||= {}
        name = customer_data[:name].to_s.strip
        raise ParseError, "Müşteri adı okunamadı." if name.blank?

        code = customer_data[:code].to_s.strip.presence
        return Customer.find_by(code: code) || new_customer(customer_data, name, code: code) if code

        tax_number = customer_data[:tax_number].to_s.strip.presence
        return Customer.find_by(tax_number: tax_number) || new_customer(customer_data, name, tax_number: tax_number) if tax_number

        Customer.find_by("lower(name) = ?", name.downcase) || new_customer(customer_data, name)
      end

      def new_customer(customer_data, name, code: nil, tax_number: nil)
        Customer.create!(
          name: name,
          code: code,
          tax_number: tax_number || customer_data[:tax_number].to_s.strip.presence,
          tax_office: customer_data[:tax_office].to_s.strip.presence,
          address: customer_data[:address].to_s.strip.presence,
          phone: customer_data[:phone].to_s.strip.presence
        )
      end

      def build_line(sale, line_data, discount_rate)
        line_data ||= {}
        name = line_data[:name].to_s.strip
        raise ParseError, "Bir satırda ürün adı bulunamadı." if name.blank?

        quantity = to_decimal(line_data[:quantity])
        raise ParseError, "\"#{name}\" satırında miktar okunamadı." unless quantity&.positive?

        list_price = to_decimal(line_data[:unit_price]) || 0
        unit_price = (list_price * (1 - discount_rate / 100)).round(2)
        vat_rate = line_data[:vat_rate].present? ? to_decimal(line_data[:vat_rate]) : nil
        unit = UNIT_ALIASES[line_data[:unit].to_s.strip.downcase]

        # Belgedeki kod bizim iç Product.code'umuza geçirilmiyor — farklı
        # müşterilerin belgelerinde aynı kod farklı ürünlere ait olabilir,
        # bizim code alanımız unique olduğu için çakışma riski var. Eşleşme
        # isimle yapılıyor, iç kod Product'ın kendi otomatik üretimine bırakılır.
        product = Products::FindOrCreate.call(name: name, unit: unit, fallback_to_default: true)
        @newly_created_products << product.name if product.previously_new_record?

        sale.sale_lines.create!(
          product: product,
          quantity: quantity,
          unit_price: unit_price,
          vat_rate: vat_rate || DEFAULT_VAT_RATE
        )
      rescue ActiveRecord::RecordInvalid => e
        raise ParseError, "\"#{name}\" satırı eklenemedi: #{e.record.errors.full_messages.join(', ')}"
      end

      def to_decimal(value)
        return nil if value.blank?
        BigDecimal(value.to_s)
      rescue ArgumentError
        nil
      end

      def parse_date(value)
        return nil if value.blank?
        Date.parse(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end
  end
end
