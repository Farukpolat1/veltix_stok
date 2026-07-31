class SupplierPayment < ApplicationRecord
  acts_as_tenant(:company)
  belongs_to :supplier
  belongs_to :user
  has_one_attached :uploaded_pdfs
  has_one_attached :receipt

  validates :amount, numericality: { greater_than: 0 }
  validates :paid_at, presence: true
end
