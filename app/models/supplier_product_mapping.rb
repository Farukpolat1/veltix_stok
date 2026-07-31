class SupplierProductMapping < ApplicationRecord
  acts_as_tenant(:company)
  belongs_to :supplier
  belongs_to :product

  validates :external_code, presence: true, uniqueness: { scope: :supplier_id }
end
