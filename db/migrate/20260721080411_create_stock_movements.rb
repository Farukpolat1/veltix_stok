class CreateStockMovements < ActiveRecord::Migration[8.1]
  def change
    create_table :stock_movements do |t|
      t.references :product, null: false, foreign_key: true
      t.references :source, polymorphic: true, null: false
      t.integer :direction, null: false
      t.decimal :quantity, null: false
      t.datetime :occurred_at, null: false
      t.references :user, null: false, foreign_key: true
      t.text :note

      t.timestamps
    end
  end
end
