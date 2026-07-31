require "test_helper"

class CompanySettingsControllerTest < ActionDispatch::IntegrationTest
  test "admin can view and update their own company's branding" do
    admin = users(:one)
    admin.update!(role: :admin)
    sign_in_as admin

    get edit_company_settings_path
    assert_response :success

    patch company_settings_path, params: { company: { name: "Yeni Firma Adı", phone: "555 555 55 55", tax_number: "1234567890" } }

    assert_redirected_to edit_company_settings_path
    admin.company.reload
    assert_equal "Yeni Firma Adı", admin.company.name
    assert_equal "1234567890", admin.company.tax_number
  end

  test "non-admin cannot edit company settings" do
    depo_user = users(:two)
    depo_user.update!(role: :depo)
    sign_in_as depo_user

    get edit_company_settings_path
    assert_redirected_to root_path
  end
end
