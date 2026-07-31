class SaleLine < ApplicationRecord
  belongs_to :sale
  belongs_to :product
  has_one :stock_movement, as: :source, dependent: :destroy

  validates :quantity, numericality: { greater_than: 0 }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }
  validates :vat_rate, numericality: { greater_than_or_equal_to: 0 }

  def subtotal
    quantity * unit_price
  end

  def vat_amount
    subtotal * vat_rate / 100
  end

  def total_with_vat
    subtotal + vat_amount
  end

  # Stok yetersizliği artık satır eklenirken değil, Sale#approvable? ile
  # onay anında engellenir (bkz. sale.rb). Satır ekleme sırasında engellemek,
  # PDF'ten içe aktarılan ve henüz stokta olmayan yeni bir ürün varsa TÜM
  # içe aktarmayı iptal ediyordu — halbuki satış beklemede kalıp sadece
  # onaylanamamalı, oluşturulması engellenmemeli.
  def insufficient_stock?
    quantity > product.stock_quantity
  end
end
