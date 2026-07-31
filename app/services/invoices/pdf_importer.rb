require "base64"
require "bigdecimal"
require "bigdecimal/util"

module Invoices
  # Taranmış/PDF fatura okuma — Gemini API'ye PDF'i doğrudan gönderip fatura
  # numarası, tarihi, tedarikçi bilgisi ve satırları (JSON) olarak çıkarır. İki
  # aşamalıdır: #extract sadece okur (hiçbir kayıt oluşturmaz), kullanıcı bu
  # veriyi bir önizleme ekranında gözden geçirip düzeltir; onayladığında
  # #persist gerçek PurchaseInvoice + PurchaseInvoiceLine kayıtlarını oluşturur.
  # UBL XML akışıyla aynı sonuca ulaşır (bkz. Invoices::UblImporter): pending
  # bir PurchaseInvoice oluşturur. Ürün eşleşmesi daha önce yapılmışsa
  # (SupplierProductMapping) onu kullanır; yoksa isimle eşleşen ürünü bulur ya
  # da (Products::FindOrCreate ile) yeni ürün olarak otomatik oluşturur — satır
  # hiçbir zaman eşleşmemiş (product_id boş) kalmaz; yanlış eşleşirse kullanıcı
  # yine de eşleştirme ekranından düzeltebilir.
  class PdfImporter
    DEFAULT_VAT_RATE = 20

    EXTRACTION_TOOL = {
      name: "extract_invoice",
      description: "Faturadan çıkarılan yapılandırılmış veriyi kaydeder.",
      input_schema: {
        type: "object",
        properties: {
          invoice_number: { type: "string", description: "Fatura numarası" },
          invoice_date: { type: "string", description: "Fatura tarihi, YYYY-MM-DD formatında" },
          supplier: {
            type: "object",
            properties: {
              name: { type: "string", description: "Tedarikçi/satıcı firma adı" },
              tax_number: { type: "string", description: "Tedarikçinin VKN/TCKN numarası, faturada yoksa boş bırak" },
              tax_office: { type: "string", description: "Tedarikçinin vergi dairesi, faturada yoksa boş bırak" },
              address: { type: "string", description: "Tedarikçinin açık adresi (mahalle/sokak/ilçe/il dahil tek satır), faturada yoksa boş bırak" },
              phone: { type: "string", description: "Tedarikçinin telefonu, faturada yoksa boş bırak" }
            },
            required: [ "name" ]
          },
          lines: {
            type: "array",
            description: "Faturadaki her bir ürün/hizmet satırı",
            items: {
              type: "object",
              properties: {
                code: { type: "string", description: "Ürün/stok kodu, faturada yoksa boş bırak" },
                name: { type: "string", description: "Ürün adı" },
                quantity: { type: "number", description: "Miktar" },
                unit_price: { type: "number", description: "KDV hariç birim fiyat" },
                vat_rate: { type: "number", description: "KDV oranı (yüzde olarak, örn. 20). Belirtilmemişse 20 varsay." }
              },
              required: [ "name", "quantity", "unit_price" ]
            }
          }
        },
        required: [ "invoice_number", "invoice_date", "supplier", "lines" ]
      }
    }.freeze

    class ParseError < StandardError; end

    def initialize(pdf_binary = nil, created_by: nil)
      @pdf_binary = pdf_binary
      @created_by = created_by
    end

    # Faz 1 — sadece okur, hiçbir kayıt oluşturmaz.
    def extract
      extract_with_gemini
    end

    # Faz 2 — (muhtemelen kullanıcı tarafından düzenlenmiş) veriyi kaydeder.
    def persist(data)
      invoice_number = data[:invoice_number].to_s.strip.presence or raise ParseError, "Fatura numarası okunamadı."
      invoice_date = parse_date(data[:invoice_date]) or raise ParseError, "Fatura tarihi okunamadı."
      lines = Array(data[:lines])
      raise ParseError, "Faturada satır bulunamadı." if lines.empty?

      PurchaseInvoice.transaction do
        supplier = find_or_create_supplier(data[:supplier])

        invoice = PurchaseInvoice.create!(
          supplier: supplier,
          created_by: @created_by,
          invoice_number: invoice_number,
          invoice_date: invoice_date
        )

        lines.each { |line| build_line(invoice, supplier, line) }

        invoice
      end
    end

    # Geriye dönük uyumluluk / tek adımda okuyup kaydetmek isteyenler için.
    def call
      persist(extract)
    end

    # Zaten var olan bir faturaya, PDF'ten okunan satırları ekler — tedarikçi
    # zaten belli olduğu için sadece ürün satırları işlenir (bkz. items sayfası
    # "PDF'ten Ürün Ekle").
    def persist_lines(invoice, lines_data)
      lines = Array(lines_data)
      raise ParseError, "Belgede satır bulunamadı." if lines.empty?

      PurchaseInvoice.transaction { lines.each { |line| build_line(invoice, invoice.supplier, line) } }
      invoice
    end

    private
      def extract_with_gemini
        Gemini::DocumentExtractor.call(
          pdf_binary: @pdf_binary,
          prompt: "Bu PVC/donanım/pencere sektörü tedarikçisinden gelen alış faturasıdır. " \
                  "Fatura numarasını, tarihini, tedarikçi adını ve VKN/TCKN'sini (varsa), " \
                  "ve faturadaki tüm ürün satırlarını (ad, kod varsa, miktar, KDV hariç birim fiyat, KDV oranı) çıkar.",
          tool_name: EXTRACTION_TOOL[:name],
          tool_description: EXTRACTION_TOOL[:description],
          input_schema: EXTRACTION_TOOL[:input_schema]
        )
      rescue Gemini::DocumentExtractor::ExtractionError => e
        raise ParseError, e.message
      end

      def find_or_create_supplier(supplier_data)
        supplier_data ||= {}
        name = supplier_data[:name].to_s.strip
        raise ParseError, "Tedarikçi adı okunamadı." if name.blank?

        tax_number = supplier_data[:tax_number].to_s.strip.presence
        return Supplier.find_by(tax_number: tax_number) || new_supplier(supplier_data, name, tax_number: tax_number) if tax_number

        Supplier.find_by("lower(name) = ?", name.downcase) || new_supplier(supplier_data, name)
      end

      def new_supplier(supplier_data, name, tax_number: nil)
        Supplier.create!(
          name: name,
          tax_number: tax_number || supplier_data[:tax_number].to_s.strip.presence,
          tax_office: supplier_data[:tax_office].to_s.strip.presence,
          address: supplier_data[:address].to_s.strip.presence,
          phone: supplier_data[:phone].to_s.strip.presence
        )
      end

      def build_line(invoice, supplier, line_data)
        line_data ||= {}
        name = line_data[:name].to_s.strip
        raise ParseError, "Bir satırda ürün adı bulunamadı." if name.blank?

        code = line_data[:code].to_s.strip.presence || name
        quantity = to_decimal(line_data[:quantity])
        raise ParseError, "\"#{name}\" satırında miktar okunamadı." unless quantity&.positive?

        unit_price = to_decimal(line_data[:unit_price]) || 0
        vat_rate = line_data[:vat_rate].present? ? to_decimal(line_data[:vat_rate]) : nil

        mapping = SupplierProductMapping.find_by(supplier_id: supplier.id, external_code: code)
        product_id = mapping&.product_id

        unless product_id
          # Tedarikçinin kendi ürün kodu (external_code) bizim iç Product.code'umuza
          # geçirilmiyor — iki farklı tedarikçi aynı kodu farklı ürünler için
          # kullanabilir, bizim code alanımız unique olduğu için çakışma riski var.
          # Eşleştirme zaten SupplierProductMapping ile (supplier_id + external_code)
          # yapılıyor; iç kod Product'ın kendi otomatik üretimine bırakılır.
          product = Products::FindOrCreate.call(name: name, fallback_to_default: true)
          product_id = product.id
          SupplierProductMapping.find_or_create_by!(supplier_id: supplier.id, external_code: code) do |m|
            m.external_name = name
            m.product_id = product_id
          end
        end

        invoice.purchase_invoice_lines.create!(
          external_code: code,
          external_name: name,
          quantity: quantity,
          unit_price: unit_price,
          vat_rate: vat_rate || DEFAULT_VAT_RATE,
          product_id: product_id
        )
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
