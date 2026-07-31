class Warehouse < ApplicationRecord
  belongs_to :company
  acts_as_tenant :company
  has_many :stock_movements, dependent: :restrict_with_error
end
