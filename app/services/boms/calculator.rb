module Boms
  # Bir ProductTemplate'i somut ölçülerle (genişlik/yükseklik/kanat sayısı vb.
  # kullanıcının girdiği ölçüler) birleştirip her satır için önerilen ürün ve
  # miktarı üretir. Sonuç DOĞRUDAN stoktan düşmez — çağıran taraf (onay
  # ekranı) bunu gözden geçirip SaleLine/PurchaseInvoiceLine olarak
  # oluşturduğunda gerçek stok hareketi Sale/PurchaseInvoice#approve! ile
  # oluşur (bkz. mevcut approve! akışı — burada tekrarlanmıyor).
  #
  # measurements: TemplateLine::MEASUREMENT_KEYS'teki anahtarları taşıyan bir
  # hash (ör. { perimeter_mm: 4200, glass_area_m2: 1.8 }) — sadece şablonda
  # kullanılan ölçü türleri gerekli, hepsini vermek şart değil.
  # product_overrides: { template_line_id => product_id } — onay ekranında
  # kullanıcı varsayılan ürün yerine aynı kategoriden başka bir ürün (ör.
  # kolun onlarca çeşidinden biri) seçtiyse.
  class Calculator
    Result = Struct.new(:template_line, :product, :quantity, keyword_init: true)

    class MissingMeasurementError < StandardError; end

    # hardware_schema_lookup satırları (ör. "Çift Açılım Donanımı") sabit
    # adet değil, kanadın genişlik×yükseklik ölçüsüne göre değişen bir KİT
    # döndürür (bkz. HardwareSchemaCell) — bu yüzden tek satırdan birden
    # çok Result çıkabilir. Bu ölçü, diğer satırların kullandığı
    # perimeter_mm/glass_area_m2 gibi türetilmiş ölçülerden ayrı, ham
    # genislik_mm/yukseklik_mm anahtarlarıyla verilir.

    # Uzunluk bazlı ölçüler (perimeter/sash_perimeter/glass_perimeter/
    # total_profile_length) mm cinsinden girilir (bkz. TemplateLine::
    # MEASUREMENT_KEYS'in _mm son ekli anahtarları) ama profil ürünleri
    # metretül (metre) biriminde stoklanıyor — bu yüzden formül mm
    # uzayında hesaplanıp SONUNDA metreye çevrilir. glass_area zaten m²
    # olduğu için çevrilmez, fixed zaten birimsizdir.
    MM_TO_M_VARIABLES = %w[perimeter sash_perimeter glass_perimeter total_profile_length].freeze

    def self.call(product_template, measurements: {}, product_overrides: {})
      new(product_template, measurements: measurements, product_overrides: product_overrides).call
    end

    def initialize(product_template, measurements: {}, product_overrides: {})
      @product_template = product_template
      @measurements = measurements.symbolize_keys
      @product_overrides = product_overrides.transform_keys(&:to_i)
    end

    def call
      product_template.template_lines.flat_map do |line|
        if line.hardware_schema_lookup?
          resolve_hardware_kit(line)
        else
          [ Result.new(template_line: line, product: resolve_product(line), quantity: resolve_quantity(line)) ]
        end
      end
    end

    private
      attr_reader :product_template, :measurements, :product_overrides

      def resolve_hardware_kit(line)
        genislik_mm = measurements[:genislik_mm]
        yukseklik_mm = measurements[:yukseklik_mm]
        if genislik_mm.nil? || yukseklik_mm.nil?
          raise MissingMeasurementError, "\"#{line.label}\" için genislik_mm/yukseklik_mm ölçüsü verilmedi."
        end

        HardwareResolver.call(
          system: line.hardware_system, acilim_tipi: line.hardware_acilim_tipi,
          genislik_mm: genislik_mm, yukseklik_mm: yukseklik_mm
        ).map do |hw|
          Result.new(template_line: line, product: hw.product, quantity: hw.quantity.to_f)
        end
      end

      def resolve_product(line)
        override_id = product_overrides[line.id]
        override_id ? Product.find(override_id) : line.default_product
      end

      def resolve_quantity(line)
        return line.fixed_quantity.to_f if line.fixed?

        measurement_key = TemplateLine::MEASUREMENT_KEYS.fetch(line.variable)
        value = measurements[measurement_key]
        raise MissingMeasurementError, "\"#{line.label}\" için #{measurement_key} ölçüsü verilmedi." if value.nil?

        raw = (value.to_f * line.coefficient.to_f * line.waste_factor.to_f) + line.offset_mm.to_f
        MM_TO_M_VARIABLES.include?(line.variable) ? raw / 1000.0 : raw
      end
  end
end
