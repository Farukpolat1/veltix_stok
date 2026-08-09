require "test_helper"

class SupportRequestsControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    post support_requests_path, params: { support_request: { message: "Bir sorum var." } }
    assert_redirected_to new_session_path
  end

  test "valid submission creates a record, enqueues a notification email and redirects back" do
    sign_in_as users(:one)

    assert_difference "SupportRequest.count", 1 do
      assert_enqueued_emails 1 do
        post support_requests_path, params: { support_request: { category: "bug", subject: "Soru", message: "Bir sorum var." } }, headers: { "HTTP_REFERER" => products_url }
      end
    end

    assert_redirected_to products_url
    support_request = SupportRequest.last
    assert_equal users(:one), support_request.user
    assert support_request.pending?
  end

  test "blank message redirects back with an alert instead of creating a record" do
    sign_in_as users(:one)

    assert_no_difference "SupportRequest.count" do
      assert_no_enqueued_emails do
        post support_requests_path, params: { support_request: { subject: "Soru", message: "" } }
      end
    end

    assert_redirected_to root_path
    assert_equal "Mesaj boş bırakılamaz", flash[:alert]
  end

  test "index only shows the current user's own requests" do
    seller = users(:one)
    sign_in_as seller
    mine = SupportRequest.create!(company: seller.company, user: seller, message: "Benim talebim")
    other_user = users(:two)
    SupportRequest.create!(company: other_user.company, user: other_user, message: "Başkasının talebi")

    get support_requests_path

    assert_response :success
    assert_includes response.body, mine.message
    assert_not_includes response.body, "Başkasının talebi"
  end

  test "super admin sees pending requests from every company" do
    admin = users(:one)
    admin.update!(super_admin: true)
    sign_in_as admin

    other_company = companies(:two)
    other_user = User.create!(company: other_company, name: "Diğer Firma Kullanıcısı", email_address: "other-company-user@example.com", password: "password123", confirmed_at: Time.current)
    cross_company_request = ActsAsTenant.with_tenant(other_company) { SupportRequest.create!(company: other_company, user: other_user, message: "Başka firmadan talep") }

    get support_requests_path

    assert_response :success
    assert_includes response.body, cross_company_request.message
  end

  test "a regular user cannot reply to a request" do
    seller = users(:one)
    sign_in_as seller
    support_request = SupportRequest.create!(company: seller.company, user: seller, message: "Talep")

    patch support_request_path(support_request), params: { support_request: { reply: "Cevap denemesi" } }

    assert_redirected_to root_path
    assert_not support_request.reload.answered?
  end

  test "super admin can reply, which marks the request as answered" do
    admin = users(:one)
    admin.update!(super_admin: true)
    sign_in_as admin
    support_request = SupportRequest.create!(company: admin.company, user: admin, message: "Talep")

    patch support_request_path(support_request), params: { support_request: { reply: "İlgileniyoruz." } }

    assert_redirected_to support_requests_path
    support_request.reload
    assert support_request.answered?
    assert_equal "İlgileniyoruz.", support_request.reply
    assert support_request.replied_at.present?
  end
end
