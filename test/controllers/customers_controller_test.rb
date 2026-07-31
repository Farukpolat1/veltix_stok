require "test_helper"

class CustomersControllerTest < ActionDispatch::IntegrationTest
  test "index renders successfully" do
    users(:one).update!(role: :admin)
    sign_in_as users(:one)

    get customers_path

    assert_response :success
  end

  test "index renders successfully when filtering by il" do
    users(:one).update!(role: :admin)
    sign_in_as users(:one)
    Customer.create!(name: "İl Filtre Testi", il: "İstanbul")

    get customers_path(il: "İstanbul")

    assert_response :success
    assert_includes @response.body, "İl Filtre Testi"
  end

  test "index renders successfully when searching by name" do
    users(:one).update!(role: :admin)
    sign_in_as users(:one)

    get customers_path(q: "hiçbirsey_eslesmeyecek")

    assert_response :success
  end
end
