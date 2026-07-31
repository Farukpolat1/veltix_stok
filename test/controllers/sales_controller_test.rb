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
end
