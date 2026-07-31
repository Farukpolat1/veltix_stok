class AddVatRateToPurchaseInvoiceLinesAndSaleLines < ActiveRecord::Migration[8.1]
  def change
    add_column :purchase_invoice_lines, :vat_rate, :decimal, default: 20, null: false
    add_column :sale_lines, :vat_rate, :decimal, default: 20, null: false
  end
end
