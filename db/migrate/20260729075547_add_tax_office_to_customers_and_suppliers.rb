class AddTaxOfficeToCustomersAndSuppliers < ActiveRecord::Migration[8.1]
  def change
    add_column :customers, :tax_office, :string
    add_column :suppliers, :tax_office, :string
  end
end
