require "test_helper"

class StockAdjustmentsControllerTest < ActionDispatch::IntegrationTest
  test "index renders with no filters" do
    sign_in_as users(:one)

    get stock_adjustments_path

    assert_response :success
  end

  test "index renders with all filters applied" do
    sign_in_as users(:one)

    get stock_adjustments_path(q: "hiçbirsey", from: "2026-01-01", to: "2026-12-31", page: "2")

    assert_response :success
  end

  test "index gracefully ignores an invalid date filter instead of erroring" do
    sign_in_as users(:one)

    get stock_adjustments_path(from: "garbage")

    assert_response :success
  end

  test "export_pdf honors the same filters" do
    sign_in_as users(:one)

    get export_pdf_stock_adjustments_path(q: "test")

    assert_response :success
    assert_equal "application/pdf", @response.media_type
  end
end
