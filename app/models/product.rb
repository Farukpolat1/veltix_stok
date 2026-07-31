class Product < ApplicationRecord
  acts_as_tenant(:company)
  belongs_to :category
  has_many :supplier_product_mappings, dependent: :destroy
  has_many :stock_movements, dependent: :restrict_with_error

  enum :unit, { adet: 0, koli: 1, kutu: 2, mt: 3, mtul: 4, paket: 5, m2: 6 }

  UNIT_LABELS = { "adet" => "Adet", "koli" => "Koli", "kutu" => "Kutu", "mt" => "Metre", "mtul" => "Metretül", "paket" => "Paket", "m2" => "m²" }.freeze

  validates :code, presence: true, uniqueness: { scope: :company_id }
  validates :name, presence: true
  validates :min_stock_level, :stock_quantity, numericality: { greater_than_or_equal_to: 0 }

  before_validation :generate_code, if: -> { code.blank? }

  def low_stock?
    stock_quantity <= min_stock_level
  end

  def unit_label
    UNIT_LABELS[unit]
  end

  private
    def generate_code
      base = name.to_s.parameterize(separator: "-").upcase.first(20).sub(/-+\z/, "")
      base = "URUN" if base.blank?
      candidate = base
      n = 1
      while Product.where(code: candidate).where.not(id: id).exists?
        n += 1
        candidate = "#{base}-#{n}"
      end
      self.code = candidate
    end
end
