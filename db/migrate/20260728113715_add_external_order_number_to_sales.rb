class AddExternalOrderNumberToSales < ActiveRecord::Migration[8.1]
  def change
    add_column :sales, :external_order_number, :string
  end
end
