module Pdf
  # Pdf::ReceiptGenerator ve Pdf::CustomerStatementGenerator'ın ortak antetli
  # kağıt mantığı — font kaydı, logo + başlık, alt bilgi şeridi. Marka bilgisi
  # (isim/adres/telefon/logo) artık firmaya (Company) ait — PDF her zaman
  # kimliği doğrulanmış bir istek içinde üretildiği için ActsAsTenant.current_tenant
  # üzerinden okunur, her çağıran yerin ayrıca company geçirmesi gerekmez.
  module Letterhead
    FONT_DIR = Rails.root.join("app/assets/fonts")

    def register_fonts(pdf)
      pdf.font_families.update(
        "DejaVuSans" => {
          normal: FONT_DIR.join("DejaVuSans.ttf").to_s,
          bold: FONT_DIR.join("DejaVuSans-Bold.ttf").to_s
        }
      )
      pdf.font "DejaVuSans"
    end

    def draw_header(pdf, title)
      company = ActsAsTenant.current_tenant
      top = pdf.cursor

      pdf.bounding_box([ 0, top ], width: pdf.bounds.width - 110) do
        if company&.logo&.attached?
          # Logo görselinin kendisi genelde sloganı içerir, ayrıca yazmıyoruz.
          pdf.image StringIO.new(company.logo.download), height: 42
        else
          pdf.text company&.name.presence || "Firma", size: 17, style: :bold
          pdf.text company.slogan, size: 9, color: "6b7280" if company&.slogan.present?
        end
      end

      pdf.move_down 14
      pdf.text title, size: 14, style: :bold
      pdf.move_down 8
    end

    def draw_footer(pdf)
      company = ActsAsTenant.current_tenant
      return unless company

      pdf.move_down 14
      pdf.stroke_color "cbd5e1"
      pdf.stroke_horizontal_rule
      pdf.stroke_color "000000"
      pdf.move_down 6
      pdf.text [ company.name, company.address ].compact_blank.join(" — "), size: 8, color: "6b7280", align: :center
      contact_line = [ company.phone.present? ? "Tel: #{company.phone}" : nil, company.website, company.email ].compact_blank.join("  ·  ")
      pdf.text contact_line, size: 8, color: "6b7280", align: :center if contact_line.present?
      tax_line = [ company.tax_number.present? ? "VKN: #{company.tax_number}" : nil, company.tax_office.present? ? "V.D.: #{company.tax_office}" : nil ].compact_blank.join("  ·  ")
      pdf.text tax_line, size: 8, color: "6b7280", align: :center if tax_line.present?
    end

    def number(value)
      return "" if value.blank?
      ActiveSupport::NumberHelper.number_to_delimited(value.to_f.round(2), delimiter: ".", separator: ",")
    end
  end
end
