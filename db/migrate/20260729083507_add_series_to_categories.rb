class AddSeriesToCategories < ActiveRecord::Migration[8.1]
  def change
    add_column :categories, :series, :string
  end
end
