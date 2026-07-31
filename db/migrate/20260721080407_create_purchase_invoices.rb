class CreatePurchaseInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table :purchase_invoices do |t|
      t.references :supplier, null: false, foreign_key: true
      t.string :invoice_number, null: false
      t.date :invoice_date, null: false
      t.string :ubl_uuid
      t.integer :status, null: false, default: 0
      t.references :created_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :purchase_invoices, :ubl_uuid, unique: true
    add_index :purchase_invoices, [ :supplier_id, :invoice_number ], unique: true
  end
end
