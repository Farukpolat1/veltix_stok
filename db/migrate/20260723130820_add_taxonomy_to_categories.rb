class AddTaxonomyToCategories < ActiveRecord::Migration[8.1]
  def change
    add_column :categories, :code, :string
    add_column :categories, :product_type, :integer, default: 5, null: false # 5 = diger
    add_column :categories, :color, :string
    add_column :categories, :accessory_type, :string
    add_column :categories, :brand, :string
    add_index :categories, :code, unique: true
  end
end
