require "test_helper"

class SalesControllerTest < ActionDispatch::IntegrationTest
  test "pending sale's customer, date and order number can be corrected" do
    seller = users(:one)
    seller.update!(role: :admin)
    sign_in_as seller
    wrong_customer = Customer.create!(name: "Yanlış Müşteri")
    right_customer = Customer.create!(name: "Doğru Müşteri")
    sale = Sale.create!(sale_date: Date.current, customer: wrong_customer, created_by: seller)

    get edit_sale_path(sale)
    assert_response :success

    patch sale_path(sale), params: { sale: { customer_id: right_customer.id, sale_date: "2026-01-15", external_order_number: "SP-DUZELTME" } }

    assert_redirected_to items_sale_path(sale)
    sale.reload
    assert_equal right_customer, sale.customer
    assert_equal Date.parse("2026-01-15"), sale.sale_date
    assert_equal "SP-DUZELTME", sale.external_order_number
  end

  test "an approved sale cannot be edited" do
    seller = users(:one)
    seller.update!(role: :admin)
    sign_in_as seller
    customer = Customer.create!(name: "Onaylanmış Satış Müşterisi")
    product = products(:one)
    sale = Sale.create!(sale_date: Date.current, customer: customer, created_by: seller)
    sale.sale_lines.create!(product: product, quantity: 1, unit_price: 10, vat_rate: 20)
    product.update!(stock_quantity: 10)
    sale.approve!(user: seller)

    get edit_sale_path(sale)
    assert_redirected_to root_path

    patch sale_path(sale), params: { sale: { external_order_number: "SHOULD-NOT-APPLY" } }
    assert_redirected_to root_path
    assert_not_equal "SHOULD-NOT-APPLY", sale.reload.external_order_number
  end

  test "insufficient stock blocks approval when company's strict_stock_check is on (default)" do
    seller = users(:one)
    seller.update!(role: :admin)
    seller.company.update!(strict_stock_check: true)
    sign_in_as seller
    customer = Customer.create!(name: "Stok Yetersiz Müşteri")
    product = products(:one)
    product.update!(stock_quantity: 0)
    sale = Sale.create!(sale_date: Date.current, customer: customer, created_by: seller)
    sale.sale_lines.create!(product: product, quantity: 5, unit_price: 10, vat_rate: 20)

    patch approve_sale_path(sale)

    assert_redirected_to items_sale_path(sale)
    assert sale.reload.pending?
  end

  test "insufficient stock does not block approval when company's strict_stock_check is off" do
    seller = users(:one)
    seller.update!(role: :admin)
    seller.company.update!(strict_stock_check: false)
    sign_in_as seller
    customer = Customer.create!(name: "Stok Kontrolsüz Müşteri")
    product = products(:one)
    product.update!(stock_quantity: 0)
    sale = Sale.create!(sale_date: Date.current, customer: customer, created_by: seller)
    sale.sale_lines.create!(product: product, quantity: 5, unit_price: 10, vat_rate: 20)

    patch approve_sale_path(sale)

    assert_redirected_to sales_path
    assert sale.reload.approved?
    assert_equal(-5, product.reload.stock_quantity)
  end

  test "deleting an approved sale reverses the stock movement and restores stock_quantity" do
    seller = users(:one)
    seller.update!(role: :admin)
    sign_in_as seller
    customer = Customer.create!(name: "Silinen Satış Müşterisi")
    product = products(:one)
    product.update!(stock_quantity: 10)
    sale = Sale.create!(sale_date: Date.current, customer: customer, created_by: seller)
    sale.sale_lines.create!(product: product, quantity: 3, unit_price: 10, vat_rate: 20)
    sale.approve!(user: seller)
    assert_equal 7, product.reload.stock_quantity

    delete sale_path(sale)

    assert_redirected_to sales_path
    assert_equal 10, product.reload.stock_quantity
    assert_not Sale.exists?(sale.id)
  end

  test "satis role cannot delete an approved sale" do
    seller = users(:one)
    seller.update!(role: :satis)
    sign_in_as seller
    customer = Customer.create!(name: "Yetkisiz Silme Müşterisi")
    product = products(:one)
    product.update!(stock_quantity: 10)
    sale = Sale.create!(sale_date: Date.current, customer: customer, created_by: seller)
    sale.sale_lines.create!(product: product, quantity: 1, unit_price: 10, vat_rate: 20)
    admin = User.create!(email_address: "gecici_admin@example.com", password: "sifre1234", role: :admin, company: seller.company, confirmed_at: Time.current)
    sale.approve!(user: admin)

    delete sale_path(sale)

    assert_redirected_to root_path
    assert Sale.exists?(sale.id)
  end

  test "adding lines from a product template computes quantities and respects product overrides" do
    seller = users(:one)
    seller.update!(role: :admin)
    sign_in_as seller
    customer = Customer.create!(name: "Şablon Testi Müşterisi")
    sale = Sale.create!(sale_date: Date.current, customer: customer, created_by: seller)

    kasa_cat = Category.create!(name: "Kasa Profili Test", product_type: :profil, color: "Beyaz")
    kol_cat = Category.create!(name: "Kol Test", product_type: :aksesuar, accessory_type: "Kol")
    kasa_product = Product.create!(name: "70lik Beyaz Kasa Test", category: kasa_cat, unit: :mtul, stock_quantity: 100)
    kol_a = Product.create!(name: "Kilitli Kol Test", category: kol_cat, unit: :adet, stock_quantity: 50)
    kol_b = Product.create!(name: "Kilitsiz Kol Test", category: kol_cat, unit: :adet, stock_quantity: 50)

    template = ProductTemplate.create!(name: "70lik Sürme Test", company: seller.company)
    perimeter_line = template.template_lines.create!(
      category: kasa_cat, default_product: kasa_product, label: "Kasa Profili",
      variable: :perimeter, coefficient: 1.0, waste_factor: 1.05, offset_mm: 200
    )
    fixed_line = template.template_lines.create!(
      category: kol_cat, default_product: kol_a, label: "Kol", variable: :fixed, fixed_quantity: 2
    )

    get new_from_template_sale_path(sale, product_template_id: template.id)
    assert_response :success

    post create_from_template_sale_path(sale), params: {
      product_template_id: template.id,
      measurements: { perimeter_mm: 5000 },
      product_ids: { fixed_line.id => kol_b.id },
      unit_prices: { perimeter_line.id => 100, fixed_line.id => 50 },
      vat_rates: { perimeter_line.id => 20, fixed_line.id => 20 }
    }

    assert_redirected_to items_sale_path(sale)
    assert_equal 2, sale.sale_lines.count

    perimeter_result = sale.sale_lines.find_by(product: kasa_product)
    assert_equal (((5000 * 1.0 * 1.05) + 200) / 1000.0).round(3), perimeter_result.quantity.to_f.round(3)

    fixed_result = sale.sale_lines.find_by(product: kol_b)
    assert_equal 2.0, fixed_result.quantity.to_f
    assert_nil sale.sale_lines.find_by(product: kol_a)
  end

  test "hardware_schema_lookup line expands into a full kit based on genislik/yukseklik" do
    seller = users(:one)
    seller.update!(role: :admin)
    sign_in_as seller
    customer = Customer.create!(name: "Donanım Kiti Testi Müşterisi")
    sale = Sale.create!(sale_date: Date.current, customer: customer, created_by: seller)

    hw_cat = Category.create!(name: "Donanım Test", product_type: :aksesuar, accessory_type: "Test")
    isp = Product.create!(name: "İspanyolet Test", category: hw_cat, unit: :adet, stock_quantity: 50)
    mentese = Product.create!(name: "Menteşe Test", category: hw_cat, unit: :adet, stock_quantity: 50)

    cell = HardwareSchemaCell.create!(system: "test_sistem", acilim_tipi: "test_acilim", genislik_min_mm: 400, genislik_max_mm: 700, yukseklik_min_mm: 800, yukseklik_max_mm: 1200)
    cell.hardware_schema_lines.create!(product: isp, quantity: 1)
    cell.hardware_schema_lines.create!(product: mentese, quantity: 2)

    template = ProductTemplate.create!(name: "Donanım Kiti Şablonu Test", company: seller.company)
    template.template_lines.create!(
      category: hw_cat, label: "Donanım Kiti", variable: :fixed, fixed_quantity: 1,
      hardware_schema_lookup: true, hardware_system: "test_sistem", hardware_acilim_tipi: "test_acilim"
    )

    get new_from_template_sale_path(sale, product_template_id: template.id)
    assert_response :success
    assert_match "otomatik seçilip eklenecek", @response.body

    post create_from_template_sale_path(sale), params: {
      product_template_id: template.id,
      measurements: { genislik_mm: 500, yukseklik_mm: 1000 }
    }

    assert_redirected_to items_sale_path(sale)
    assert_equal 2, sale.sale_lines.count
    assert_equal 1.0, sale.sale_lines.find_by(product: isp).quantity.to_f
    assert_equal 2.0, sale.sale_lines.find_by(product: mentese).quantity.to_f
  end
end
