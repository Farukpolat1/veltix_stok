# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_09_080415) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "categories", force: :cascade do |t|
    t.string "accessory_type"
    t.string "brand"
    t.string "code"
    t.string "color"
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "custom_attributes", default: {}, null: false
    t.string "name"
    t.integer "product_type", default: 2, null: false
    t.string "series"
    t.datetime "updated_at", null: false
    t.index ["company_id", "code"], name: "index_categories_on_company_id_and_code", unique: true
    t.index ["company_id"], name: "index_categories_on_company_id"
  end

  create_table "category_option_groups", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "name"], name: "index_category_option_groups_on_company_id_and_name", unique: true
    t.index ["company_id"], name: "index_category_option_groups_on_company_id"
  end

  create_table "category_options", force: :cascade do |t|
    t.bigint "category_option_group_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["category_option_group_id", "name"], name: "index_category_options_on_category_option_group_id_and_name", unique: true
    t.index ["category_option_group_id"], name: "index_category_options_on_category_option_group_id"
  end

  create_table "companies", force: :cascade do |t|
    t.text "address"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name", null: false
    t.string "phone"
    t.string "slogan"
    t.string "tax_number"
    t.string "tax_office"
    t.datetime "updated_at", null: false
    t.string "website"
  end

  create_table "customer_payments", force: :cascade do |t|
    t.decimal "amount", null: false
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.text "note"
    t.datetime "paid_at", null: false
    t.integer "payment_method", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["company_id"], name: "index_customer_payments_on_company_id"
    t.index ["customer_id"], name: "index_customer_payments_on_customer_id"
    t.index ["user_id"], name: "index_customer_payments_on_user_id"
  end

  create_table "customers", force: :cascade do |t|
    t.text "address"
    t.string "code"
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.string "il"
    t.string "name", null: false
    t.decimal "opening_balance", default: "0.0", null: false
    t.string "phone"
    t.string "tax_number"
    t.string "tax_office"
    t.datetime "updated_at", null: false
    t.index ["company_id", "code"], name: "index_customers_on_company_id_and_code", unique: true
    t.index ["company_id", "tax_number"], name: "index_customers_on_company_id_and_tax_number", unique: true
    t.index ["company_id"], name: "index_customers_on_company_id"
  end

  create_table "hardware_schema_cells", force: :cascade do |t|
    t.string "acilim_tipi", null: false
    t.datetime "created_at", null: false
    t.integer "genislik_max_mm", null: false
    t.integer "genislik_min_mm", null: false
    t.string "system", null: false
    t.datetime "updated_at", null: false
    t.integer "yukseklik_max_mm", null: false
    t.integer "yukseklik_min_mm", null: false
    t.index ["system", "acilim_tipi", "genislik_min_mm", "yukseklik_min_mm"], name: "idx_hw_cells_lookup"
  end

  create_table "hardware_schema_lines", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "hardware_schema_cell_id", null: false
    t.bigint "product_id", null: false
    t.decimal "quantity", precision: 10, scale: 2, default: "1.0", null: false
    t.datetime "updated_at", null: false
    t.index ["hardware_schema_cell_id"], name: "index_hardware_schema_lines_on_hardware_schema_cell_id"
    t.index ["product_id"], name: "index_hardware_schema_lines_on_product_id"
  end

  create_table "product_templates", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code"
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "name"], name: "index_product_templates_on_company_id_and_name", unique: true
    t.index ["company_id"], name: "index_product_templates_on_company_id"
  end

  create_table "products", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.string "code"
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.decimal "min_stock_level", default: "0.0"
    t.string "name"
    t.decimal "stock_quantity", default: "0.0", null: false
    t.integer "unit"
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_products_on_category_id"
    t.index ["company_id", "code"], name: "index_products_on_company_id_and_code", unique: true
    t.index ["company_id"], name: "index_products_on_company_id"
  end

  create_table "purchase_invoice_lines", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "external_code", null: false
    t.string "external_name", null: false
    t.bigint "product_id"
    t.bigint "purchase_invoice_id", null: false
    t.decimal "quantity", null: false
    t.decimal "unit_price", null: false
    t.datetime "updated_at", null: false
    t.decimal "vat_rate", default: "20.0", null: false
    t.index ["product_id"], name: "index_purchase_invoice_lines_on_product_id"
    t.index ["purchase_invoice_id"], name: "index_purchase_invoice_lines_on_purchase_invoice_id"
  end

  create_table "purchase_invoices", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.date "invoice_date", null: false
    t.string "invoice_number", null: false
    t.integer "status", default: 0, null: false
    t.bigint "supplier_id", null: false
    t.string "ubl_uuid"
    t.datetime "updated_at", null: false
    t.index ["company_id", "ubl_uuid"], name: "index_purchase_invoices_on_company_id_and_ubl_uuid", unique: true
    t.index ["company_id"], name: "index_purchase_invoices_on_company_id"
    t.index ["created_by_id"], name: "index_purchase_invoices_on_created_by_id"
    t.index ["supplier_id", "invoice_number"], name: "index_purchase_invoices_on_supplier_id_and_invoice_number", unique: true
    t.index ["supplier_id"], name: "index_purchase_invoices_on_supplier_id"
  end

  create_table "sale_lines", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "product_id", null: false
    t.decimal "quantity", null: false
    t.bigint "sale_id", null: false
    t.decimal "unit_price", null: false
    t.datetime "updated_at", null: false
    t.decimal "vat_rate", default: "20.0", null: false
    t.index ["product_id"], name: "index_sale_lines_on_product_id"
    t.index ["sale_id"], name: "index_sale_lines_on_sale_id"
  end

  create_table "sales", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.bigint "customer_id", null: false
    t.string "external_order_number"
    t.date "sale_date", null: false
    t.string "sale_number", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "sale_number"], name: "index_sales_on_company_id_and_sale_number", unique: true
    t.index ["company_id"], name: "index_sales_on_company_id"
    t.index ["created_by_id"], name: "index_sales_on_created_by_id"
    t.index ["customer_id"], name: "index_sales_on_customer_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "stock_adjustments", force: :cascade do |t|
    t.datetime "adjusted_at", null: false
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.bigint "product_id", null: false
    t.decimal "quantity_after", null: false
    t.decimal "quantity_before", null: false
    t.text "reason", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["company_id"], name: "index_stock_adjustments_on_company_id"
    t.index ["product_id"], name: "index_stock_adjustments_on_product_id"
    t.index ["user_id"], name: "index_stock_adjustments_on_user_id"
  end

  create_table "stock_movements", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.integer "direction", null: false
    t.text "note"
    t.datetime "occurred_at", null: false
    t.bigint "product_id", null: false
    t.decimal "quantity", null: false
    t.bigint "source_id", null: false
    t.string "source_type", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["company_id"], name: "index_stock_movements_on_company_id"
    t.index ["product_id"], name: "index_stock_movements_on_product_id"
    t.index ["source_type", "source_id"], name: "index_stock_movements_on_source"
    t.index ["user_id"], name: "index_stock_movements_on_user_id"
  end

  create_table "supplier_categories", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.bigint "supplier_id", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_supplier_categories_on_category_id"
    t.index ["supplier_id", "category_id"], name: "index_supplier_categories_on_supplier_and_category", unique: true
    t.index ["supplier_id"], name: "index_supplier_categories_on_supplier_id"
  end

  create_table "supplier_payments", force: :cascade do |t|
    t.decimal "amount", null: false
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.text "note"
    t.datetime "paid_at", null: false
    t.bigint "supplier_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["company_id"], name: "index_supplier_payments_on_company_id"
    t.index ["supplier_id"], name: "index_supplier_payments_on_supplier_id"
    t.index ["user_id"], name: "index_supplier_payments_on_user_id"
  end

  create_table "supplier_product_mappings", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.string "external_code", null: false
    t.string "external_name"
    t.bigint "product_id", null: false
    t.bigint "supplier_id", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_supplier_product_mappings_on_company_id"
    t.index ["product_id"], name: "index_supplier_product_mappings_on_product_id"
    t.index ["supplier_id", "external_code"], name: "index_supplier_mappings_on_supplier_and_code", unique: true
    t.index ["supplier_id"], name: "index_supplier_product_mappings_on_supplier_id"
  end

  create_table "suppliers", force: :cascade do |t|
    t.text "address"
    t.string "code"
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.decimal "opening_balance", default: "0.0", null: false
    t.string "phone"
    t.string "tax_number"
    t.string "tax_office"
    t.datetime "updated_at", null: false
    t.index ["company_id", "code"], name: "index_suppliers_on_company_id_and_code", unique: true
    t.index ["company_id", "tax_number"], name: "index_suppliers_on_company_id_and_tax_number", unique: true
    t.index ["company_id"], name: "index_suppliers_on_company_id"
  end

  create_table "support_requests", force: :cascade do |t|
    t.integer "category", default: 0, null: false
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.text "message", null: false
    t.datetime "replied_at"
    t.text "reply"
    t.integer "status", default: 0, null: false
    t.string "subject"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["company_id"], name: "index_support_requests_on_company_id"
    t.index ["user_id"], name: "index_support_requests_on_user_id"
  end

  create_table "template_lines", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.decimal "coefficient", precision: 10, scale: 4, default: "1.0", null: false
    t.datetime "created_at", null: false
    t.bigint "default_product_id"
    t.decimal "fixed_quantity", precision: 10, scale: 2
    t.string "hardware_acilim_tipi"
    t.boolean "hardware_schema_lookup", default: false, null: false
    t.string "hardware_system"
    t.string "label", null: false
    t.decimal "offset_mm", precision: 10, scale: 2, default: "0.0", null: false
    t.integer "position", default: 0, null: false
    t.bigint "product_template_id", null: false
    t.datetime "updated_at", null: false
    t.integer "variable", default: 5, null: false
    t.decimal "waste_factor", precision: 6, scale: 4, default: "1.0", null: false
    t.index ["category_id"], name: "index_template_lines_on_category_id"
    t.index ["default_product_id"], name: "index_template_lines_on_default_product_id"
    t.index ["product_template_id"], name: "index_template_lines_on_product_template_id"
  end

  create_table "users", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "name"
    t.string "password_digest", null: false
    t.integer "role", default: 1, null: false
    t.boolean "super_admin", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_users_on_company_id"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "warehouses", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_warehouses_on_company_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "categories", "companies"
  add_foreign_key "category_option_groups", "companies"
  add_foreign_key "category_options", "category_option_groups"
  add_foreign_key "customer_payments", "companies"
  add_foreign_key "customer_payments", "customers"
  add_foreign_key "customer_payments", "users"
  add_foreign_key "customers", "companies"
  add_foreign_key "hardware_schema_lines", "hardware_schema_cells"
  add_foreign_key "hardware_schema_lines", "products"
  add_foreign_key "product_templates", "companies"
  add_foreign_key "products", "categories"
  add_foreign_key "products", "companies"
  add_foreign_key "purchase_invoice_lines", "products"
  add_foreign_key "purchase_invoice_lines", "purchase_invoices"
  add_foreign_key "purchase_invoices", "companies"
  add_foreign_key "purchase_invoices", "suppliers"
  add_foreign_key "purchase_invoices", "users", column: "created_by_id"
  add_foreign_key "sale_lines", "products"
  add_foreign_key "sale_lines", "sales"
  add_foreign_key "sales", "companies"
  add_foreign_key "sales", "customers"
  add_foreign_key "sales", "users", column: "created_by_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "stock_adjustments", "companies"
  add_foreign_key "stock_adjustments", "products"
  add_foreign_key "stock_adjustments", "users"
  add_foreign_key "stock_movements", "companies"
  add_foreign_key "stock_movements", "products"
  add_foreign_key "stock_movements", "users"
  add_foreign_key "supplier_categories", "categories"
  add_foreign_key "supplier_categories", "suppliers"
  add_foreign_key "supplier_payments", "companies"
  add_foreign_key "supplier_payments", "suppliers"
  add_foreign_key "supplier_payments", "users"
  add_foreign_key "supplier_product_mappings", "companies"
  add_foreign_key "supplier_product_mappings", "products"
  add_foreign_key "supplier_product_mappings", "suppliers"
  add_foreign_key "suppliers", "companies"
  add_foreign_key "support_requests", "companies"
  add_foreign_key "support_requests", "users"
  add_foreign_key "template_lines", "categories"
  add_foreign_key "template_lines", "product_templates"
  add_foreign_key "template_lines", "products", column: "default_product_id"
  add_foreign_key "users", "companies"
  add_foreign_key "warehouses", "companies"
end
