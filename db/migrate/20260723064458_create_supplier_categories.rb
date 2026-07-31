class CreateSupplierCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :supplier_categories do |t|
      t.references :supplier, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true

      t.timestamps
    end

    add_index :supplier_categories, [ :supplier_id, :category_id ], unique: true
  end
end
