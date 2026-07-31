module CustomerPayments
  # Müşteriden gelen dekont/makbuz PDF'ini okuyup Yeni Tahsilat formunu
  # otomatik doldurur — hiçbir kayıt oluşturmaz, kullanıcı formu kontrol edip
  # normal create ile kaydeder (bkz. Products::PdfReader — aynı tek-belge,
  # inceleme-sonrası-kaydet deseni).
  class PdfReader
    EXTRACTION_TOOL = {
      name: "extract_customer_payment",
      description: "Dekont/makbuzdan çıkarılan tahsilat bilgisini kaydeder.",
      input_schema: {
        type: "object",
        properties: {
          amount: { type: "number", description: "Ödenen/tahsil edilen tutar" },
          paid_at: { type: "string", description: "Ödeme tarihi, YYYY-MM-DD formatında" },
          payment_method: {
            type: "string",
            description: "Ödeme yöntemi: Nakit, Banka Havalesi, Kredi Kartı, Çek, Diğer değerlerinden biri. Belgeden anlaşılamıyorsa \"Banka Havalesi\" varsay (dekontlar genelde havale/EFT'dir)."
          },
          note: { type: "string", description: "Varsa açıklama/dekont notu, yoksa boş bırak" }
        },
        required: [ "amount" ]
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
        prompt: "Bu bir banka dekontu, EFT/havale makbuzu ya da tahsilat belgesidir. " \
                "Tutarı, ödeme tarihini, ödeme yöntemini (Nakit/Banka Havalesi/Kredi Kartı/Çek/Diğer) " \
                "ve varsa açıklama notunu çıkar.",
        tool_name: EXTRACTION_TOOL[:name],
        tool_description: EXTRACTION_TOOL[:description],
        input_schema: EXTRACTION_TOOL[:input_schema]
      )

      {
        amount: data[:amount],
        paid_at: parse_date(data[:paid_at]) || Date.current,
        payment_method: CustomerPayment::PAYMENT_METHOD_LABELS.key(data[:payment_method].to_s.strip) || "banka_havalesi",
        note: data[:note].to_s.strip.presence
      }
    rescue Gemini::DocumentExtractor::ExtractionError => e
      raise ParseError, e.message
    end

    private
      def parse_date(value)
        return nil if value.blank?
        Date.parse(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end
  end
end
