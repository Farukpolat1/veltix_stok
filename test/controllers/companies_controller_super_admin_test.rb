require "test_helper"

class CompaniesControllerSuperAdminTest < ActionDispatch::IntegrationTest
  test "super admin can create a brand new company with its first admin user" do
    owner = users(:one)
    owner.update!(role: :admin, super_admin: true)
    sign_in_as owner

    get companies_path
    assert_response :success

    assert_difference [ "Company.count", "User.count" ], 1 do
      post companies_path, params: {
        company: { name: "Yeni Test Firması", phone: "555 555 55 55" },
        admin: { name: "Yeni Firma Yöneticisi", email_address: "yeni-firma-admin@example.com", password: "password123", password_confirmation: "password123" }
      }
    end

    assert_redirected_to companies_path
    new_company = Company.find_by!(name: "Yeni Test Firması")
    new_admin = User.find_by!(email_address: "yeni-firma-admin@example.com")
    assert_equal new_company, new_admin.company
    assert new_admin.admin?
    assert_not new_admin.confirmed?
    assert_enqueued_email_with ConfirmationsMailer, :confirm, args: [ new_admin ]

    ActsAsTenant.with_tenant(new_company) do
      assert_equal 21, Category.count
      assert_equal 4, CategoryOptionGroup.count
    end
  end

  test "regular admin (not super_admin) cannot access the companies platform screen" do
    regular_admin = users(:one)
    regular_admin.update!(role: :admin, super_admin: false)
    sign_in_as regular_admin

    get companies_path
    assert_redirected_to root_path

    assert_no_difference "Company.count" do
      post companies_path, params: { company: { name: "Yetkisiz Firma" }, admin: { email_address: "x@example.com", password: "password123" } }
    end
  end

  test "super admin can edit and update another company's info, including tax fields" do
    owner = users(:one)
    owner.update!(role: :admin, super_admin: true)
    sign_in_as owner

    other_company = Company.create!(name: "Başka Firma")

    get edit_company_path(other_company)
    assert_response :success

    patch company_path(other_company), params: { company: { name: "Güncellenmiş Firma", tax_number: "1112223334", tax_office: "Kadıköy" } }

    assert_redirected_to companies_path
    other_company.reload
    assert_equal "Güncellenmiş Firma", other_company.name
    assert_equal "1112223334", other_company.tax_number
    assert_equal "Kadıköy", other_company.tax_office
  end

  test "super admin can permanently delete a company and everything inside it" do
    owner = users(:one)
    owner.update!(role: :admin, super_admin: true)
    sign_in_as owner

    target_company = Company.create!(name: "Silinecek Firma")
    target_admin = target_customer = nil
    ActsAsTenant.with_tenant(target_company) do
      target_admin = User.create!(name: "Hedef Admin", email_address: "hedef-admin@example.com", password: "password123", password_confirmation: "password123", role: :admin, company: target_company)
      target_customer = Customer.create!(name: "Hedef Müşteri")
    end

    delete company_path(target_company)

    assert_redirected_to companies_path
    assert_nil Company.find_by(id: target_company.id)
    ActsAsTenant.without_tenant do
      assert_nil User.find_by(id: target_admin.id)
      assert_nil Customer.find_by(id: target_customer.id)
    end
  end

  test "regular admin (not super_admin) cannot edit or delete another company" do
    regular_admin = users(:one)
    regular_admin.update!(role: :admin, super_admin: false)
    sign_in_as regular_admin

    other_company = Company.create!(name: "Diğer Firma")

    get edit_company_path(other_company)
    assert_redirected_to root_path

    assert_no_difference "Company.count" do
      delete company_path(other_company)
    end
  end

  test "super admin can switch into another company's data and back to their own" do
    owner = users(:one)
    owner.update!(role: :admin, super_admin: true)
    sign_in_as owner

    other_company = Company.create!(name: "Hedef Firma")
    ActsAsTenant.with_tenant(other_company) { Customer.create!(name: "Hedef Müşteri") }

    post impersonate_company_path(other_company)
    assert_redirected_to root_path

    get customers_path
    assert_response :success
    assert_match "Hedef Müşteri", response.body

    delete stop_impersonating_companies_path
    assert_redirected_to companies_path

    get customers_path
    assert_response :success
    assert_no_match "Hedef Müşteri", response.body
  end

  test "regular admin (not super_admin) cannot impersonate another company" do
    regular_admin = users(:one)
    regular_admin.update!(role: :admin, super_admin: false)
    sign_in_as regular_admin

    other_company = Company.create!(name: "Hedef Firma")

    post impersonate_company_path(other_company)
    assert_redirected_to root_path
  end
end
