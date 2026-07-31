class Customer < ApplicationRecord
  acts_as_tenant(:company)
  has_many :sales, dependent: :restrict_with_error
  has_many :customer_payments, dependent: :destroy

  validates :name, presence: true
  validates :tax_number, uniqueness: { scope: :company_id }, allow_blank: true
  validates :code, uniqueness: { scope: :company_id }, allow_blank: true

  def total_sold
    sale_ids = sales.approved.pluck(:id)
    SaleLine.where(sale_id: sale_ids).sum("quantity * unit_price * (1 + vat_rate / 100)")
  end

  def total_paid
    customer_payments.sum(:amount)
  end

  # opening_balance eski muhasebe programından aktarılan devir bakiyesidir —
  # sistem öncesi cari geçmişi olmayan yeni müşterilerde 0'dır.
  def balance
    opening_balance + total_sold - total_paid
  end

  # Liste ekranlarında müşteri başına balance çağırmak N+1'e yol açar (735 cari
  # ile ~3000 sorgu). Bunun yerine tüm müşteriler için tek seferde toplu hesaplar.
  def self.balances_for(customers)
    ids = customers.map(&:id)
    sold = SaleLine.joins(:sale)
      .where(sales: { customer_id: ids, status: Sale.statuses[:approved] })
      .group("sales.customer_id")
      .sum("sale_lines.quantity * sale_lines.unit_price * (1 + sale_lines.vat_rate / 100)")
    paid = CustomerPayment.where(customer_id: ids).group(:customer_id).sum(:amount)

    customers.index_by(&:id).transform_values do |customer|
      customer.opening_balance + (sold[customer.id] || 0) - (paid[customer.id] || 0)
    end
  end
end
