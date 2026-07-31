require "prawn"
require "prawn/table"

module Pdf
  # Tedarikçi cari hesap ekstresi — Pdf::CustomerStatementGenerator'ın Alış
  # tarafındaki simetriği. Devir bakiyesi + onaylı alış faturaları (borç) +
  # tedarikçiye yapılan ödemeler (alacak), koşan bakiye ile.
  class SupplierStatementGenerator
    include Letterhead

    def self.call(supplier:)
      new(supplier).call
    end

    def initialize(supplier)
      @supplier = supplier
    end

    def call
      Prawn::Document.new(page_size: "A4", margin: 40) do |pdf|
        register_fonts(pdf)
        draw_header(pdf, "Cari Hesap Ekstresi")

        pdf.text "Tedarikçi: #{@supplier.name}"
        pdf.text "Cari Kodu: #{@supplier.code}" if @supplier.code.present?
        pdf.text "Tarih: #{Date.current.strftime('%d.%m.%Y')}"
        pdf.move_down 15

        rows = [ [ "Tarih", "Açıklama", "Borç", "Alacak", "Bakiye" ] ]
        running = @supplier.opening_balance

        if @supplier.opening_balance.nonzero?
          rows << [ "-", "Devir Bakiyesi", "", "", number(running) ]
        end

        movements.each do |entry|
          if entry[:type] == :invoice
            running += entry[:amount]
            rows << [ entry[:date].strftime("%d.%m.%Y"), "Fatura ##{entry[:ref]}", number(entry[:amount]), "", number(running) ]
          else
            running -= entry[:amount]
            note = entry[:ref].presence
            label = note ? "Ödeme (#{note})" : "Ödeme"
            rows << [ entry[:date].strftime("%d.%m.%Y"), label, "", number(entry[:amount]), number(running) ]
          end
        end

        pdf.table(rows, header: true, width: pdf.bounds.width) do |t|
          t.row(0).font_style = :bold
          t.row(0).background_color = "EEEEEE"
          t.cells.padding = 6
          t.cells.size = 9
          t.columns(2..4).align = :right
        end

        pdf.move_down 10
        pdf.text "Güncel Bakiye: #{number(@supplier.balance)} ₺", size: 12, style: :bold, align: :right

        draw_footer(pdf)
      end.render
    end

    private
      def movements
        invoices = @supplier.purchase_invoices.approved.includes(:purchase_invoice_lines).map do |invoice|
          { type: :invoice, date: invoice.invoice_date, ref: invoice.invoice_number, amount: invoice.purchase_invoice_lines.sum(&:total_with_vat) }
        end
        payments = @supplier.supplier_payments.map do |payment|
          { type: :payment, date: payment.paid_at.to_date, ref: payment.note, amount: payment.amount }
        end
        (invoices + payments).sort_by { |entry| entry[:date] }
      end
  end
end
