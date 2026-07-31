class CreateSupplierProductMappings < ActiveRecord::Migration[8.1]
  def change
    create_table :supplier_product_mappings do |t|
      t.references :supplier, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.string :external_code, null: false
      t.string :external_name

      t.timestamps
    end

    add_index :supplier_product_mappings, [ :supplier_id, :external_code ], unique: true, name: "index_supplier_mappings_on_supplier_and_code"
  end
end
