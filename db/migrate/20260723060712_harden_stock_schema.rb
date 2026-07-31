class HardenStockSchema < ActiveRecord::Migration[8.1]
  def change
    # suppliers: name zorunlu, VKN/TCKN tekil olmalı
    change_column_null :suppliers, :name, false
    add_index :suppliers, :tax_number, unique: true

    # supplier_product_mappings: tedarikçi kodu zorunlu ve tedarikçi başına tekil
    change_column_null :supplier_product_mappings, :external_code, false
    add_index :supplier_product_mappings, [ :supplier_id, :external_code ], unique: true,
      name: "index_supplier_mappings_on_supplier_and_code"

    # purchase_invoice_lines: ürün eşleştirilene kadar product_id boş olabilmeli
    change_column_null :purchase_invoice_lines, :product_id, true
    change_column_null :purchase_invoice_lines, :external_code, false
    change_column_null :purchase_invoice_lines, :external_name, false
    change_column_null :purchase_invoice_lines, :quantity, false
    change_column_null :purchase_invoice_lines, :unit_price, false

    # sales
    change_column_default :sales, :status, from: nil, to: 0
    execute "UPDATE sales SET status = 0 WHERE status IS NULL"
    change_column_null :sales, :status, false
    change_column_null :sales, :sold_at, false

    # sale_lines
    change_column_null :sale_lines, :quantity, false
    change_column_null :sale_lines, :unit_price, false

    # stock_movements
    change_column_null :stock_movements, :direction, false
    change_column_null :stock_movements, :quantity, false
    change_column_null :stock_movements, :occurred_at, false
  end
end
