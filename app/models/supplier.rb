class Supplier < ApplicationRecord
  acts_as_tenant(:company)
  has_many :supplier_product_mappings, dependent: :destroy
  has_many :purchase_invoices, dependent: :restrict_with_error
  has_many :supplier_categories, dependent: :destroy
  has_many :categories, through: :supplier_categories
  has_many :supplier_payments, dependent: :destroy

  validates :name, presence: true
  validates :tax_number, uniqueness: { scope: :company_id }, allow_blank: true
  validates :code, uniqueness: { scope: :company_id }, allow_blank: true

  def total_purchased
    invoice_ids = purchase_invoices.approved.pluck(:id)
    PurchaseInvoiceLine.where(purchase_invoice_id: invoice_ids).sum("quantity * unit_price * (1 + vat_rate / 100)")
  end

  def total_paid
    supplier_payments.sum(:amount)
  end

  # opening_balance eski muhasebe programından aktarılan devir bakiyesidir —
  # sistem öncesi cari geçmişi olmayan yeni tedarikçilerde 0'dır.
  def balance
    opening_balance + total_purchased - total_paid
  end

  # Liste ekranlarında tedarikçi başına balance çağırmak N+1'e yol açar
  # (bkz. Customer.balances_for) — tüm tedarikçiler için tek seferde hesaplar.
  def self.balances_for(suppliers)
    ids = suppliers.map(&:id)
    purchased = PurchaseInvoiceLine.joins(:purchase_invoice)
      .where(purchase_invoices: { supplier_id: ids, status: PurchaseInvoice.statuses[:approved] })
      .group("purchase_invoices.supplier_id")
      .sum("purchase_invoice_lines.quantity * purchase_invoice_lines.unit_price * (1 + purchase_invoice_lines.vat_rate / 100)")
    paid = SupplierPayment.where(supplier_id: ids).group(:supplier_id).sum(:amount)

    suppliers.index_by(&:id).transform_values do |supplier|
      supplier.opening_balance + (purchased[supplier.id] || 0) - (paid[supplier.id] || 0)
    end
  end
end
