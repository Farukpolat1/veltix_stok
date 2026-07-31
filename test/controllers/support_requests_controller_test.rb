require "test_helper"

class SupportRequestsControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    post support_requests_path, params: { support_request: { message: "Bir sorum var." } }
    assert_redirected_to new_session_path
  end

  test "valid submission enqueues a notification email and redirects back" do
    sign_in_as users(:one)

    assert_enqueued_emails 1 do
      post support_requests_path, params: { support_request: { subject: "Soru", message: "Bir sorum var." } }, headers: { "HTTP_REFERER" => products_url }
    end

    assert_redirected_to products_url
  end

  test "blank message redirects back with an alert instead of sending mail" do
    sign_in_as users(:one)

    assert_no_enqueued_emails do
      post support_requests_path, params: { support_request: { subject: "Soru", message: "" } }
    end

    assert_redirected_to root_path
    assert_equal "Mesaj boş bırakılamaz", flash[:alert]
  end
end
