class CreateStockAdjustments < ActiveRecord::Migration[8.1]
  def change
    create_table :stock_adjustments do |t|
      t.references :product, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.decimal :quantity_before, null: false
      t.decimal :quantity_after, null: false
      t.text :reason, null: false
      t.datetime :adjusted_at, null: false

      t.timestamps
    end
  end
end
