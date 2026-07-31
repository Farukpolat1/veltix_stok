class CreateSupplierPayments < ActiveRecord::Migration[8.1]
  def change
    create_table :supplier_payments do |t|
      t.references :supplier, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.decimal :amount, null: false
      t.datetime :paid_at, null: false
      t.text :note

      t.timestamps
    end
  end
end
