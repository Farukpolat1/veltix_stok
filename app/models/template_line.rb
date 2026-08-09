# Bir ProductTemplate satırı: "hangi kategoriden, ne kadar" kuralı.
# BomCalculator bunu bir Sale/PurchaseInvoice'a dönüştürürken:
#   miktar = (variable'a karşılık gelen ölçü * coefficient * waste_factor) + offset_mm
# variable :fixed ise ölçüden bağımsız olarak fixed_quantity kullanılır (Faz 1'in tek yolu).
#
# default_product sadece bir ÖNERİ — kol gibi tek kategoride onlarca çeşit
# olabileceğinden, onay ekranında kullanıcı candidate_products'tan (aynı
# category'deki tüm ürünler) başka birini seçebilir.
class TemplateLine < ApplicationRecord
  belongs_to :product_template
  belongs_to :category
  belongs_to :default_product, class_name: "Product", optional: true

  enum :variable, {
    perimeter: 0,
    sash_perimeter: 1,
    glass_perimeter: 2,
    glass_area: 3,
    total_profile_length: 4,
    fixed: 5
  }, default: :fixed

  # Boms::Calculator'ın measurements hash'inde bu değişkenler için hangi
  # anahtarı arayacağını belirtir (ör. variable: "glass_area" ise
  # measurements[:glass_area_m2] okunur).
  MEASUREMENT_KEYS = {
    "perimeter" => :perimeter_mm,
    "sash_perimeter" => :sash_perimeter_mm,
    "glass_perimeter" => :glass_perimeter_mm,
    "glass_area" => :glass_area_m2,
    "total_profile_length" => :total_profile_length_mm
  }.freeze

  VARIABLE_LABELS = {
    "perimeter" => "Çevre (mm)",
    "sash_perimeter" => "Kanat Çevresi (mm)",
    "glass_perimeter" => "Cam Çevresi (mm)",
    "glass_area" => "Cam Alanı (m²)",
    "total_profile_length" => "Toplam Profil Uzunluğu (mm)",
    "fixed" => "Sabit Miktar"
  }.freeze

  validates :label, presence: true
  validates :coefficient, :waste_factor, :offset_mm, presence: true
  validates :fixed_quantity, presence: true, if: -> { fixed? && !hardware_schema_lookup? }
  validates :hardware_system, :hardware_acilim_tipi, presence: true, if: :hardware_schema_lookup?

  def variable_label
    VARIABLE_LABELS[variable]
  end

  # Onay ekranında bu satır için seçilebilecek ürünler — aynı kategori
  # içindeki hepsi (ör. "Kol" kategorisindeki tüm kol çeşitleri).
  def candidate_products
    category.products.order(:name)
  end
end
