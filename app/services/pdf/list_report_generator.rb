require "prawn"
require "prawn/table"

module Pdf
  # Herhangi bir liste ekranını (Satışlar, Alış Faturaları, Ürünler, Stok
  # Hareketleri, Müşteriler, Tedarikçiler, Kategoriler, Stok Sayımı) PDF'e
  # döken genel amaçlı üretici — sayfa yatay, tek tablo, altta kayıt sayısı.
  class ListReportGenerator
    include Letterhead

    def self.call(title:, headers:, rows:, subtitle: nil)
      new(title, headers, rows, subtitle).call
    end

    def initialize(title, headers, rows, subtitle)
      @title = title
      @headers = headers
      @rows = rows
      @subtitle = subtitle
    end

    def call
      Prawn::Document.new(page_size: "A4", margin: 36, page_layout: :landscape) do |pdf|
        register_fonts(pdf)
        draw_header(pdf, @title)
        pdf.text @subtitle, size: 9, color: "6b7280" if @subtitle.present?
        pdf.move_down 8

        if @rows.empty?
          pdf.text "Kayıt bulunamadı.", size: 10, color: "6b7280"
        else
          table_rows = [ @headers ] + @rows
          pdf.table(table_rows, header: true, width: pdf.bounds.width) do |t|
            t.row(0).font_style = :bold
            t.row(0).background_color = "EEEEEE"
            t.cells.padding = 5
            t.cells.size = 8
          end
        end

        pdf.move_down 10
        pdf.text "Toplam Kayıt: #{@rows.size}", size: 9, color: "6b7280"

        draw_footer(pdf)
      end.render
    end
  end
end
