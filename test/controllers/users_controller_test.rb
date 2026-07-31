require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "company admin only sees and manages their own company's users" do
    admin = users(:one)
    admin.update!(role: :admin)
    sign_in_as admin

    other_company = Company.create!(name: "Başka Firma")
    other_user = nil
    ActsAsTenant.with_tenant(other_company) do
      other_user = User.create!(name: "Başka Firma Çalışanı", email_address: "baska-calisan@example.com", password: "password123", password_confirmation: "password123", role: :depo, company: other_company)
    end

    get users_path
    assert_response :success
    assert_no_match "Başka Firma Çalışanı", response.body

    get edit_user_path(other_user)
    assert_redirected_to root_path

    assert_no_difference "User.count" do
      delete user_path(other_user)
    end
  end

  test "new user is always created under the currently viewed company, not a picked one" do
    admin = users(:one)
    admin.update!(role: :admin)
    sign_in_as admin

    assert_difference "User.count", 1 do
      post users_path, params: { user: { name: "Yeni Çalışan", email_address: "yeni-calisan@example.com", password: "password123", password_confirmation: "password123", role: "depo" } }
    end

    new_user = User.find_by!(email_address: "yeni-calisan@example.com")
    assert_equal admin.company, new_user.company
  end

  test "super admin only sees their own company's users unless impersonating another company" do
    owner = users(:one)
    owner.update!(role: :admin, super_admin: true)
    sign_in_as owner

    other_company = Company.create!(name: "Hedef Firma")
    other_user = nil
    ActsAsTenant.with_tenant(other_company) do
      other_user = User.create!(name: "Hedef Firma Çalışanı", email_address: "hedef-calisan@example.com", password: "password123", password_confirmation: "password123", role: :depo, company: other_company)
    end

    get users_path
    assert_response :success
    assert_no_match "Hedef Firma Çalışanı", response.body

    post impersonate_company_path(other_company)

    get users_path
    assert_response :success
    assert_match "Hedef Firma Çalışanı", response.body
    assert_no_match users(:two).email_address, response.body
  end
end
