class AddStrictStockCheckToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :strict_stock_check, :boolean, null: false, default: true
  end
end
