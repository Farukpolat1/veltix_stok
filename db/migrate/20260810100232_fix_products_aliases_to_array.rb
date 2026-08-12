class FixProductsAliasesToArray < ActiveRecord::Migration[8.1]
  def up
    remove_column :products, :aliases
    add_column :products, :aliases, :string, array: true, default: [], null: false
    add_index :products, :aliases, using: :gin
  end

  def down
    remove_column :products, :aliases
    add_column :products, :aliases, :string
  end
end
