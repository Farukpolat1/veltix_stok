# Stoktaki her değişikliğin (satış, alış, üretim, sayım düzeltmesi...) tek
# ortak kaydı burasıdır — hangi işlem sebep olduysa `source` polymorphic
# ilişkisiyle ona işaret eder. Product.stock_quantity'yi elle güncellemek
# yerine her zaman bir StockMovement oluşturun; gerçek güncelleme aşağıdaki
# callback'te tek yerden yapılır.
class StockMovement < ApplicationRecord
  acts_as_tenant(:company)
  belongs_to :product
  belongs_to :source, polymorphic: true
  belongs_to :user

  enum :direction, { in: 0, out: 1 }

  validates :quantity, numericality: { greater_than: 0 }
  validates :occurred_at, presence: true

  after_create :apply_to_product_stock

  def source_label
    case source
    when PurchaseInvoiceLine then "Alış Faturası ##{source.purchase_invoice.invoice_number}"
    when SaleLine then "Satış ##{source.sale.sale_number}"
    when StockAdjustment then "Stok Düzeltme (#{source.reason.truncate(30)})"
    end
  end

  private
    def apply_to_product_stock
      delta = in? ? quantity : -quantity
      product.increment!(:stock_quantity, delta)
    end
end
