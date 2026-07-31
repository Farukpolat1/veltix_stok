require "prawn"
require "prawn/table"

module Pdf
  # Alış faturası ve satış fişi için ortak PDF çıktısı — ikisi de aynı
  # başlık/tablo/toplam yapısını kullanır, sadece etiketler ve veri farklı.
  # Türkçe karakterler için DejaVuSans fontu kayıtlı (Prawn'ın varsayılan
  # Helvetica'sı ğ/ş/ı/ö/ü/ç karakterlerini basamaz).
  class ReceiptGenerator
    include Letterhead

    def self.call(...)
      new(...).call
    end

    def initialize(title:, doc_number:, doc_date:, status_label:, counterparty_label:, counterparty_name:, lines:)
      @title = title
      @doc_number = doc_number
      @doc_date = doc_date
      @status_label = status_label
      @counterparty_label = counterparty_label
      @counterparty_name = counterparty_name
      @lines = lines
    end

    def call
      Prawn::Document.new(page_size: "A4", margin: 40) do |pdf|
        register_fonts(pdf)
        draw_header(pdf, @title)

        pdf.text "#{@counterparty_label}: #{@counterparty_name}"
        pdf.text "Belge No: #{@doc_number}"
        pdf.text "Tarih: #{@doc_date}"
        pdf.text "Durum: #{@status_label}"
        pdf.move_down 15

        rows = [ [ "Ürün", "Miktar", "Birim Fiyat", "KDV %", "Toplam" ] ]
        @lines.each do |line|
          rows << [
            line[:name],
            "#{number(line[:quantity])} #{line[:unit_label]}",
            "#{number(line[:unit_price])} ₺",
            "%#{line[:vat_rate].to_i}",
            "#{number(line[:total_with_vat])} ₺"
          ]
        end

        pdf.table(rows, header: true, width: pdf.bounds.width) do |t|
          t.row(0).font_style = :bold
          t.row(0).background_color = "EEEEEE"
          t.cells.padding = 6
          t.cells.size = 10
        end

        pdf.move_down 10
        grand_total = @lines.sum { |line| line[:total_with_vat] }
        pdf.text "Genel Toplam: #{number(grand_total)} ₺", size: 12, style: :bold, align: :right

        draw_footer(pdf)
      end.render
    end
  end
end
