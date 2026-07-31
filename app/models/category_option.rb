# Bir CategoryOptionGroup altındaki tek bir değer — ör. "Marka" grubunun
# altında "Egepen", "Vorne"; "Kalınlık" gibi yönetici tarafından sonradan
# açılan bir grubun altında da yönetici kendi değerlerini ekleyebilir.
class CategoryOption < ApplicationRecord
  belongs_to :category_option_group

  validates :name, presence: true, uniqueness: { scope: :category_option_group_id }

  scope :ordered, -> { order(:name) }
end
