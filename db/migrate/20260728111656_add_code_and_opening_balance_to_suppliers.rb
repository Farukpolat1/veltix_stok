class AddCodeAndOpeningBalanceToSuppliers < ActiveRecord::Migration[8.1]
  def change
    add_column :suppliers, :code, :string
    add_column :suppliers, :opening_balance, :decimal, default: 0, null: false
    add_index :suppliers, :code, unique: true
  end
end
