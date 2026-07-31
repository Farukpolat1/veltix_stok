# Kategori formunda kullanılan özellik grupları (Marka, Renk, Aksesuar Alt
# Türü, Seri baştan gelir) — yönetici kendi yeni grubunu da (ör. "Kalınlık",
# "Cam Tipi") ekleyip altına kendi değerlerini (CategoryOption) girebilir.
# Marka/Renk/Aksesuar Alt Türü/Seri, Category'nin kendi sabit sütunlarına
# (brand/color/accessory_type/series) karşılık gelir; bunların dışında
# eklenen özel gruplar Category#custom_attributes (jsonb) içine yazılır.
class CategoryOptionGroup < ApplicationRecord
  acts_as_tenant(:company)
  CORE_NAMES = [ "Marka", "Renk", "Aksesuar Alt Türü", "Seri" ].freeze

  has_many :category_options, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :company_id }

  scope :ordered, -> { order(:name) }

  def core? = CORE_NAMES.include?(name)
end
