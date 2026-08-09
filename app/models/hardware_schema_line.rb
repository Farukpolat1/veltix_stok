class HardwareSchemaLine < ApplicationRecord
  belongs_to :hardware_schema_cell
  belongs_to :product

  validates :quantity, numericality: { greater_than: 0 }
end
