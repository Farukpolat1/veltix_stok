require "nokogiri"
require "bigdecimal"
require "bigdecimal/util"

module Invoices
  # Türkiye e-Fatura/e-Arşiv (UBL-TR) XML'ini okuyup pending bir PurchaseInvoice
  # ve satırlarını oluşturur. Ürün eşleştirmesi daha önce bu tedarikçi için
  # yapılmışsa (SupplierProductMapping) onu kullanır; yapılmamışsa isimle
  # eşleşen ürünü bulur ya da (Products::FindOrCreate ile) yeni ürün olarak
  # otomatik oluşturur — kullanıcı yanlış eşleşirse yine de eşleştirme
  # ekranından düzeltebilir.
  class UblImporter
    NAMESPACES = {
      "cbc" => "urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2",
      "cac" => "urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2"
    }.freeze

    class ParseError < StandardError; end

    def initialize(xml, created_by:)
      @xml = xml
      @created_by = created_by
    end

    def call
      doc = parse_document

      invoice_number = text_at(doc, "cbc:ID").presence or raise ParseError, "Fatura numarası (cbc:ID) bulunamadı."
      issue_date = text_at(doc, "cbc:IssueDate").presence or raise ParseError, "Fatura tarihi (cbc:IssueDate) bulunamadı."
      line_nodes = doc.xpath("//cac:InvoiceLine", NAMESPACES)
      raise ParseError, "Faturada satır (cac:InvoiceLine) bulunamadı." if line_nodes.empty?

      PurchaseInvoice.transaction do
        supplier = find_or_create_supplier(doc)

        invoice = PurchaseInvoice.create!(
          supplier: supplier,
          created_by: @created_by,
          invoice_number: invoice_number,
          invoice_date: Date.parse(issue_date),
          ubl_uuid: text_at(doc, "cbc:UUID").presence
        )

        line_nodes.each { |node| build_line(invoice, supplier, node) }

        invoice
      end
    end

    private
      def parse_document
        doc = Nokogiri::XML(@xml) { |config| config.strict.nonet }
        raise ParseError, "Geçersiz XML." if doc.root.nil?
        doc
      rescue Nokogiri::XML::SyntaxError => e
        raise ParseError, "XML ayrıştırılamadı: #{e.message}"
      end

      def find_or_create_supplier(doc)
        party = doc.at_xpath("//cac:AccountingSupplierParty/cac:Party", NAMESPACES)
        raise ParseError, "Tedarikçi bilgisi (AccountingSupplierParty) bulunamadı." if party.nil?

        tax_number = text_at(party, "cac:PartyTaxScheme/cbc:CompanyID").presence ||
                     text_at(party, "cac:PartyIdentification/cbc:ID").presence
        name = text_at(party, "cac:PartyLegalEntity/cbc:RegistrationName").presence ||
               text_at(party, "cac:PartyName/cbc:Name").presence

        raise ParseError, "Tedarikçi VKN/TCKN bilgisi bulunamadı." if tax_number.blank?
        raise ParseError, "Tedarikçi adı bulunamadı." if name.blank?

        Supplier.find_or_create_by!(tax_number: tax_number) do |s|
          s.name = name
        end
      end

      def build_line(invoice, supplier, node)
        external_code = text_at(node, "cac:Item/cac:SellersItemIdentification/cbc:ID").presence ||
                         text_at(node, "cac:Item/cac:StandardItemIdentification/cbc:ID").presence
        external_name = text_at(node, "cac:Item/cbc:Name").presence
        quantity = text_at(node, "cbc:InvoicedQuantity").presence
        unit_price = text_at(node, "cac:Price/cbc:PriceAmount").presence

        raise ParseError, "Bir fatura satırında ürün kodu bulunamadı." if external_code.blank?
        raise ParseError, "#{external_code} kodlu satırda ürün adı bulunamadı." if external_name.blank?
        raise ParseError, "#{external_code} kodlu satırda miktar bulunamadı." if quantity.blank?

        mapping = SupplierProductMapping.find_by(supplier_id: supplier.id, external_code: external_code)
        product_id = mapping&.product_id

        unless product_id
          # Tedarikçinin kendi ürün kodu (external_code) bizim iç Product.code'umuza
          # geçirilmiyor — bkz. Invoices::PdfImporter'daki aynı gerekçe.
          product = Products::FindOrCreate.call(name: external_name, fallback_to_default: true)
          product_id = product.id
          SupplierProductMapping.find_or_create_by!(supplier_id: supplier.id, external_code: external_code) do |m|
            m.external_name = external_name
            m.product_id = product_id
          end
        end

        invoice.purchase_invoice_lines.create!(
          external_code: external_code,
          external_name: external_name,
          quantity: quantity.to_d,
          unit_price: unit_price.to_d,
          product_id: product_id
        )
      end

      def text_at(node, path)
        node.at_xpath(".//#{path}", NAMESPACES)&.text&.strip
      end
  end
end
