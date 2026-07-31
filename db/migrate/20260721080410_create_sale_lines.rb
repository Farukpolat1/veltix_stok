class CreateSaleLines < ActiveRecord::Migration[8.1]
  def change
    create_table :sale_lines do |t|
      t.references :sale, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.decimal :quantity, null: false
      t.decimal :unit_price, null: false

      t.timestamps
    end
  end
end
