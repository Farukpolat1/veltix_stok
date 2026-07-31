class CreateSales < ActiveRecord::Migration[8.1]
  def change
    create_table :sales do |t|
      t.references :user, null: false, foreign_key: true
      t.datetime :sold_at, null: false
      t.integer :status, null: false, default: 0

      t.timestamps
    end
  end
end
