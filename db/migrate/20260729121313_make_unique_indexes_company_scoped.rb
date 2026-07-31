class MakeUniqueIndexesCompanyScoped < ActiveRecord::Migration[8.1]
  # Bu alanların hepsi Rails validasyonunda "scope: :company_id" oldu ama
  # veritabanı indeksleri hâlâ tamamen global tekillik dayatıyordu — bu
  # yüzden iki firma aynı ürün kodunu/cari kodunu kullanamıyordu (bkz.
  # PG::UniqueViolation, ikinci firma seed edilirken bulundu).
  CHANGES = [
    [ :categories, :code, "index_categories_on_code" ],
    [ :category_option_groups, :name, "index_category_option_groups_on_name" ],
    [ :customers, :code, "index_customers_on_code" ],
    [ :customers, :tax_number, "index_customers_on_tax_number" ],
    [ :products, :code, "index_products_on_code" ],
    [ :purchase_invoices, :ubl_uuid, "index_purchase_invoices_on_ubl_uuid" ],
    [ :sales, :sale_number, "index_sales_on_sale_number" ],
    [ :suppliers, :code, "index_suppliers_on_code" ],
    [ :suppliers, :tax_number, "index_suppliers_on_tax_number" ]
  ].freeze

  def up
    CHANGES.each do |table, column, index_name|
      remove_index table, name: index_name
      add_index table, [ :company_id, column ], unique: true
    end
  end

  def down
    CHANGES.each do |table, column, index_name|
      remove_index table, column: [ :company_id, column ]
      add_index table, column, unique: true, name: index_name
    end
  end
end
