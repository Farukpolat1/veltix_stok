class CreateProductionMaterialUsages < ActiveRecord::Migration[8.1]
  def change
    create_table :production_material_usages do |t|
      t.references :production, null: false, foreign_key: true
      t.references :material, null: false, foreign_key: { to_table: :products }
      t.decimal :quantity, null: false

      t.timestamps
    end
  end
end
