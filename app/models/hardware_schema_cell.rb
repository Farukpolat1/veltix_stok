# Egepen'in ölçü-aralığına göre donanım kiti tablolarının (ör. "Vorne Çift
# Açılım Alttan Kilitlemeli") tek bir hücresi — belirli bir genişlik×yükseklik
# aralığında hangi parçalardan kaç adet gerektiğini taşır. Firma-bağımsız
# (company_id yok), Egepen'in kendi kataloğuna ait sabit bir referans.
class HardwareSchemaCell < ApplicationRecord
  has_many :hardware_schema_lines, dependent: :destroy

  validates :system, :acilim_tipi, presence: true
  validates :genislik_min_mm, :genislik_max_mm, :yukseklik_min_mm, :yukseklik_max_mm, presence: true

  def self.resolve(system:, acilim_tipi:, genislik_mm:, yukseklik_mm:)
    where(system: system, acilim_tipi: acilim_tipi)
      .where("genislik_min_mm <= ? AND genislik_max_mm >= ?", genislik_mm, genislik_mm)
      .where("yukseklik_min_mm <= ? AND yukseklik_max_mm >= ?", yukseklik_mm, yukseklik_mm)
      .first
  end
end
