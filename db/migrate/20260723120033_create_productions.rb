class CreateProductions < ActiveRecord::Migration[8.1]
  def change
    create_table :productions do |t|
      t.references :recipe, null: false, foreign_key: true
      t.decimal :quantity, null: false
      t.references :user, null: false, foreign_key: true
      t.datetime :produced_at, null: false

      t.timestamps
    end
  end
end
