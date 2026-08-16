require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    sign_in_as users(:one)
    get root_url
    assert_response :success
  end

  test "summary breaks down approved sales by dashboard_group and color" do
    admin = users(:one)
    admin.update!(role: :admin)
    sign_in_as admin

    kasa_cat = Category.create!(name: "Kasa Renk Testi", product_type: :profil, color: "Beyaz", dashboard_group: :profil_mtul)
    beyaz_kasa = Product.create!(name: "Kasa Beyaz Test", category: kasa_cat, unit: :mtul, color: "Beyaz", stock_quantity: 100)
    renkli_kasa = Product.create!(name: "Kasa Antrasit Test", category: kasa_cat, unit: :mtul, color: "Antrasit Gri", stock_quantity: 100)

    customer = Customer.create!(name: "Renk Kırılımı Müşterisi")
    sale = Sale.create!(sale_date: Date.current, customer: customer, created_by: admin)
    sale.sale_lines.create!(product: beyaz_kasa, quantity: 10, unit_price: 50, vat_rate: 20)
    sale.sale_lines.create!(product: renkli_kasa, quantity: 4, unit_price: 50, vat_rate: 20)
    sale.approve!(user: admin)

    get dashboard_summary_path(period: "day")

    assert_response :success
    assert_match "Renk Kırılımı", @response.body
    assert_match "10", @response.body
    assert_match "4", @response.body
  end
end
