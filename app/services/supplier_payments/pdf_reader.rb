module SupplierPayments
  # Tedarikçiye yapılan ödemenin dekont/makbuz PDF'ini okuyup Yeni Ödeme
  # formunu otomatik doldurur — hiçbir kayıt oluşturmaz, kullanıcı formu
  # kontrol edip normal create ile kaydeder (bkz. CustomerPayments::PdfReader
  # — aynı tek-belge, inceleme-sonrası-kaydet deseni).
  class PdfReader
    EXTRACTION_TOOL = {
      name: "extract_supplier_payment",
      description: "Dekont/makbuzdan çıkarılan ödeme bilgisini kaydeder.",
      input_schema: {
        type: "object",
        properties: {
          amount: { type: "number", description: "Ödenen tutar" },
          paid_at: { type: "string", description: "Ödeme tarihi, YYYY-MM-DD formatında" },
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
        prompt: "Bu, bir tedarikçiye yapılan ödemeye ait banka dekontu, EFT/havale makbuzu ya da ödeme belgesidir. " \
                "Tutarı, ödeme tarihini ve varsa açıklama notunu çıkar.",
        tool_name: EXTRACTION_TOOL[:name],
        tool_description: EXTRACTION_TOOL[:description],
        input_schema: EXTRACTION_TOOL[:input_schema]
      )

      {
        amount: data[:amount],
        paid_at: parse_date(data[:paid_at]) || Date.current,
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
