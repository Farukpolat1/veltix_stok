require "prawn"
require "prawn/table"

module Pdf
  # Patronun "bu ay ne oldu" diye bakabileceği özet rapor — Satış/Alış/Stok
  # Hareketi/Tahsilat-Ödeme/Bekleyen işlemler tek PDF'te. Sayılar
  # DashboardController'ın anasayfada zaten gösterdiği İş Özeti ile aynı
  # hesaplama mantığını kullanır, sadece seçilen aya göre.
  class MonthlyReportGenerator
    include Letterhead

    def self.call(month:, stats:)
      new(month, stats).call
    end

    def initialize(month, stats)
      @month = month
      @stats = stats
    end

    def call
      Prawn::Document.new(page_size: "A4", margin: 40) do |pdf|
        register_fonts(pdf)
        draw_header(pdf, "Aylık Rapor — #{month_label}")

        section(pdf, "Satış", [
          [ "Onaylı Satış Adedi", @stats[:sale_count].to_s ],
          [ "Satış Tutarı", "#{number(@stats[:sale_total])} ₺" ],
          [ "Satılan Metretül", "#{number(@stats[:sale_mtul])} mtül" ],
          [ "Satılan m²", "#{number(@stats[:sale_m2])} m²" ]
        ])

        section(pdf, "Alış", [
          [ "Onaylı Fatura Adedi", @stats[:purchase_count].to_s ],
          [ "Alış Tutarı", "#{number(@stats[:purchase_total])} ₺" ],
          [ "Alınan Metretül", "#{number(@stats[:purchase_mtul])} mtül" ],
          [ "Alınan m²", "#{number(@stats[:purchase_m2])} m²" ]
        ])

        section(pdf, "Stok Hareketi", [
          [ "Stok Girişi", number(@stats[:stock_in]) ],
          [ "Stok Çıkışı", number(@stats[:stock_out]) ]
        ])

        section(pdf, "Cari Hareketler", [
          [ "Müşteriden Tahsilat", "#{number(@stats[:customer_payments])} ₺" ],
          [ "Tedarikçiye Ödeme", "#{number(@stats[:supplier_payments])} ₺" ]
        ])

        section(pdf, "Bekleyen İşlemler (ay bağımsız, anlık)", [
          [ "Beklemede Alış Faturası", @stats[:pending_purchase_invoices].to_s ],
          [ "Beklemede Satış", @stats[:pending_sales].to_s ]
        ])

        draw_footer(pdf)
      end.render
    end

    private
      def month_label
        turkish_months = %w[Ocak Şubat Mart Nisan Mayıs Haziran Temmuz Ağustos Eylül Ekim Kasım Aralık]
        "#{turkish_months[@month.month - 1]} #{@month.year}"
      end

      def section(pdf, title, rows)
        pdf.text title, size: 12, style: :bold
        pdf.move_down 4
        pdf.table(rows, width: pdf.bounds.width) do |t|
          t.cells.padding = 6
          t.cells.size = 10
          t.column(0).font_style = :bold
          t.column(0).width = 220
        end
        pdf.move_down 14
      end
  end
end
