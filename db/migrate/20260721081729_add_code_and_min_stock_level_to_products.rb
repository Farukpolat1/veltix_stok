class AddCodeAndMinStockLevelToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :code, :string
    add_column :products, :min_stock_level, :decimal, default: 0
    change_column_default :products, :stock_quantity, 0
    change_column_null :products, :stock_quantity, false, 0

    add_index :products, :code, unique: true
  end
end
