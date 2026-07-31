module Invoices
  # Vergi levhası, fatura başlığı gibi bir firma/kişi bilgi belgesinden temel
  # cari bilgilerini okur — yeni müşteri/tedarikçi eklerken formu otomatik
  # doldurmak için kullanılır. Hiçbir kayıt oluşturmaz; sonuç doğrudan
  # Customer.new/Supplier.new'e geçirilip normal create akışında kaydedilir.
  class CompanyDocumentExtractor
    EXTRACTION_TOOL = {
      name: "extract_company_info",
      description: "Belgeden firma/kişi (cari) bilgilerini çıkarır.",
      input_schema: {
        type: "object",
        properties: {
          name: { type: "string", description: "Firma/kişi unvanı" },
          tax_number: { type: "string", description: "VKN/TCKN, belgede yoksa boş bırak" },
          tax_office: { type: "string", description: "Vergi dairesi, belgede yoksa boş bırak" },
          address: { type: "string", description: "Açık adres (mahalle/sokak/ilçe/il dahil tek satır), belgede yoksa boş bırak" },
          phone: { type: "string", description: "Telefon, belgede yoksa boş bırak" }
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
      Gemini::DocumentExtractor.call(
        pdf_binary: @pdf_binary,
        prompt: "Bu bir vergi levhası, fatura başlığı ya da firma/kişi bilgi belgesidir. " \
                "Firma/kişi unvanını, VKN/TCKN'sini, vergi dairesini, açık adresini ve " \
                "varsa telefonunu çıkar.",
        tool_name: EXTRACTION_TOOL[:name],
        tool_description: EXTRACTION_TOOL[:description],
        input_schema: EXTRACTION_TOOL[:input_schema]
      )
    rescue Gemini::DocumentExtractor::ExtractionError => e
      raise ParseError, e.message
    end
  end
end
