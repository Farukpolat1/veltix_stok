class AddTaxFieldsToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :tax_number, :string
    add_column :companies, :tax_office, :string
  end
end
