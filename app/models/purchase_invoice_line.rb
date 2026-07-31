class PurchaseInvoiceLine < ApplicationRecord
  belongs_to :purchase_invoice
  belongs_to :product, optional: true
  has_one :stock_movement, as: :source, dependent: :destroy

  validates :external_code, :external_name, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }
  validates :vat_rate, numericality: { greater_than_or_equal_to: 0 }

  after_update :upsert_supplier_mapping, if: -> { saved_change_to_product_id? && product_id.present? }

  def subtotal
    quantity * unit_price
  end

  def vat_amount
    subtotal * vat_rate / 100
  end

  def total_with_vat
    subtotal + vat_amount
  end

  private
    def upsert_supplier_mapping
      mapping = SupplierProductMapping.find_or_initialize_by(
        supplier_id: purchase_invoice.supplier_id,
        external_code: external_code
      )
      mapping.external_name = external_name
      mapping.product_id = product_id
      mapping.save!
    end
end
