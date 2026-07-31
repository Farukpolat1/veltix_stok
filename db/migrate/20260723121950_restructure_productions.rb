class RestructureProductions < ActiveRecord::Migration[8.1]
  def change
    change_column_null :productions, :recipe_id, true
    change_column_null :productions, :produced_at, true

    add_reference :productions, :product, foreign_key: true
    add_column :productions, :status, :integer, default: 0, null: false
  end
end
