class AddAliasesToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :aliases, :string, array: true, default: [], null: false
    add_index :products, :aliases, using: :gin
  end
end
