class AddBarcodeAndDefaultSalePriceToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :barcode, :string
    add_column :products, :default_sale_price, :decimal, default: 0

    add_index :products, :barcode, unique: true
  end
end
