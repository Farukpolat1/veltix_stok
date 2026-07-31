class AddCodeAndOpeningBalanceToCustomers < ActiveRecord::Migration[8.1]
  def change
    add_column :customers, :code, :string
    add_column :customers, :opening_balance, :decimal, default: 0, null: false
    add_index :customers, :code, unique: true
  end
end
