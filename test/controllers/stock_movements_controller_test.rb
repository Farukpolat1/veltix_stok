require "test_helper"

class StockMovementsControllerTest < ActionDispatch::IntegrationTest
  test "index renders with no filters" do
    sign_in_as users(:one)

    get stock_movements_path

    assert_response :success
  end

  test "index renders with all filters applied" do
    sign_in_as users(:one)

    get stock_movements_path(q: "hiçbirsey", direction: "in", from: "2026-01-01", to: "2026-12-31", page: "2")

    assert_response :success
  end

  test "index gracefully ignores an invalid date filter instead of erroring" do
    sign_in_as users(:one)

    get stock_movements_path(from: "not-a-date")

    assert_response :success
  end

  test "export_pdf honors the same filters" do
    sign_in_as users(:one)

    get export_pdf_stock_movements_path(q: "test", direction: "out")

    assert_response :success
    assert_equal "application/pdf", @response.media_type
  end

  test "source column links to the sale when the user is authorized to view it" do
    seller = users(:one)
    seller.update!(role: :admin)
    sign_in_as seller
    customer = Customer.create!(name: "Stok Hareket Test Müşterisi")
    product = products(:one)
    sale = Sale.create!(sale_date: Date.current, customer: customer, created_by: seller)
    line = sale.sale_lines.create!(product: product, quantity: 1, unit_price: 10, vat_rate: 20)
    StockMovement.create!(product: product, source: line, direction: :out, quantity: 1, occurred_at: Time.current, user: seller)

    get stock_movements_path

    assert_response :success
    assert_select "a[href=?]", items_sale_path(sale)
  end
end
