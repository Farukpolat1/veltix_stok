require "prawn"
require "prawn/table"

module Pdf
  # Müşteriye gönderilebilecek cari hesap ekstresi — devir bakiyesi, tüm
  # onaylı satışlar (borç) ve tahsilatlar (alacak) tarih sırasıyla, koşan
  # bakiye ile. Sahibinin bize gösterdiği eski muhasebe programı çıktısıyla
  # (Cari Hareket Bakiye Listesi) aynı mantık: Borç/Alacak/Bakiye.
  class CustomerStatementGenerator
    include Letterhead

    def self.call(customer:)
      new(customer).call
    end

    def initialize(customer)
      @customer = customer
    end

    def call
      Prawn::Document.new(page_size: "A4", margin: 40) do |pdf|
        register_fonts(pdf)
        draw_header(pdf, "Cari Hesap Ekstresi")

        pdf.text "Müşteri: #{@customer.name}"
        pdf.text "Cari Kodu: #{@customer.code}" if @customer.code.present?
        pdf.text "Tarih: #{Date.current.strftime('%d.%m.%Y')}"
        pdf.move_down 15

        rows = [ [ "Tarih", "Açıklama", "Borç", "Alacak", "Bakiye" ] ]
        running = @customer.opening_balance

        if @customer.opening_balance.nonzero?
          rows << [ "-", "Devir Bakiyesi", "", "", number(running) ]
        end

        movements.each do |entry|
          if entry[:type] == :sale
            running += entry[:amount]
            rows << [ entry[:date].strftime("%d.%m.%Y"), "Satış ##{entry[:ref]}", number(entry[:amount]), "", number(running) ]
          else
            running -= entry[:amount]
            note = entry[:ref].presence
            label = note ? "Tahsilat (#{note})" : "Tahsilat"
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
        pdf.text "Güncel Bakiye: #{number(@customer.balance)} ₺", size: 12, style: :bold, align: :right

        draw_footer(pdf)
      end.render
    end

    private
      def movements
        sales = @customer.sales.approved.includes(:sale_lines).map do |sale|
          { type: :sale, date: sale.sale_date, ref: sale.sale_number, amount: sale.sale_lines.sum(&:total_with_vat) }
        end
        payments = @customer.customer_payments.map do |payment|
          { type: :payment, date: payment.paid_at.to_date, ref: payment.note, amount: payment.amount }
        end
        (sales + payments).sort_by { |entry| entry[:date] }
      end
  end
end
