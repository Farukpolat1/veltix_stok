class CreatePurchaseInvoiceLines < ActiveRecord::Migration[8.1]
  def change
    create_table :purchase_invoice_lines do |t|
      t.references :purchase_invoice, null: false, foreign_key: true
      t.references :product, null: true, foreign_key: true
      t.string :external_code, null: false
      t.string :external_name, null: false
      t.decimal :quantity, null: false
      t.decimal :unit_price, null: false

      t.timestamps
    end
  end
end
