class CreateRecipes < ActiveRecord::Migration[8.1]
  def change
    create_table :recipes do |t|
      t.references :product, null: false, foreign_key: true
      t.string :name, null: false
      t.text :notes

      t.timestamps
    end
  end
end
