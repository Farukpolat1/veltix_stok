class AddCompanyToBusinessTables < ActiveRecord::Migration[8.1]
  # Detay/eşleştirme tabloları (sale_lines, purchase_invoice_lines,
  # supplier_categories, category_options) company_id almaz — zaten
  # tenant-scope'lu bir üst kayda bağlılar, scope'u ondan miras alırlar.
  TABLES = %i[
    customers suppliers products categories category_option_groups
    sales purchase_invoices stock_movements stock_adjustments
    customer_payments supplier_payments supplier_product_mappings
  ].freeze

  def up
    company_id = execute("SELECT id FROM companies ORDER BY id LIMIT 1").first.fetch("id")

    TABLES.each do |table|
      add_reference table, :company, foreign_key: true
      execute("UPDATE #{table} SET company_id = #{company_id} WHERE company_id IS NULL")
      change_column_null table, :company_id, false
    end
  end

  def down
    TABLES.each { |table| remove_reference table, :company, foreign_key: true }
  end
end
