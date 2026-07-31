class CreateRecipeItems < ActiveRecord::Migration[8.1]
  def change
    create_table :recipe_items do |t|
      t.references :recipe, null: false, foreign_key: true
      t.references :material, null: false, foreign_key: { to_table: :products }
      t.decimal :quantity_per_unit, null: false

      t.timestamps
    end
  end
end
