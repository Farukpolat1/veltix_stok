module Products
  # Tek bir ürün için teknik föy/katalog sayfası PDF'i okuyup Yeni Ürün
  # formunu otomatik doldurur — hiçbir kayıt oluşturmaz, kullanıcı formu
  # kontrol edip normal create ile kaydeder. Tüm bir kataloğu otomatik
  # kategorilere ayırıp doğrudan kaydeden Catalogs::PdfImporter'dan farklı
  # olarak burada tek ürün + inceleme adımı vardır.
  class PdfReader
    UNIT_ALIASES = {
      "mtül" => "mtul", "mtul" => "mtul", "metretül" => "mtul", "mt" => "mt", "metre" => "mt",
      "adet" => "adet", "koli" => "koli", "kutu" => "kutu", "paket" => "paket",
      "m²" => "m2", "m2" => "m2"
    }.freeze

    EXTRACTION_TOOL = {
      name: "extract_product",
      description: "Belgeden çıkarılan tek ürün bilgisini kaydeder.",
      input_schema: {
        type: "object",
        properties: {
          name: { type: "string", description: "Ürünün tam adı" },
          code: { type: "string", description: "Ürün/stok kodu, belgede yoksa boş bırak" },
          unit: { type: "string", description: "Birim: mtül, adet, m² gibi, belgede yoksa boş bırak" },
          category_name: { type: "string", description: "Ürünün ait olabileceği kategori adı (ör. \"Kasa Profili\"), belgede yoksa boş bırak" }
        },
        required: [ "name" ]
      }
    }.freeze

    class ParseError < StandardError; end

    def self.call(pdf_binary) = new(pdf_binary).call

    def initialize(pdf_binary)
      @pdf_binary = pdf_binary
    end

    def call
      data = Gemini::DocumentExtractor.call(
        pdf_binary: @pdf_binary,
        prompt: "Bu bir PVC/pencere/donanım ürününe ait teknik föy, katalog sayfası ya da ürün bilgi belgesidir. " \
                "Ürünün tam adını, varsa stok kodunu, birimini (mtül/adet/m² gibi) ve ait olabileceği " \
                "kategori adını çıkar.",
        tool_name: EXTRACTION_TOOL[:name],
        tool_description: EXTRACTION_TOOL[:description],
        input_schema: EXTRACTION_TOOL[:input_schema]
      )
      data[:unit] = UNIT_ALIASES[data[:unit].to_s.strip.downcase]
      data
    rescue Gemini::DocumentExtractor::ExtractionError => e
      raise ParseError, e.message
    end
  end
end
