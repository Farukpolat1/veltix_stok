class AddCustomerToSales < ActiveRecord::Migration[8.1]
  def change
    add_reference :sales, :customer, null: true, foreign_key: true
  end
end
