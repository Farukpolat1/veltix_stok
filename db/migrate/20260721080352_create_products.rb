class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :name
      t.references :category, null: false, foreign_key: true
      t.integer :unit
      t.decimal :stock_quantity

      t.timestamps
    end
  end
end
