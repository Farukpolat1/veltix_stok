require "test_helper"

class DemoRequestsControllerTest < ActionDispatch::IntegrationTest
  test "valid submission enqueues a notification email and redirects" do
    assert_enqueued_emails 1 do
      post demo_requests_path, params: { demo_request: { name: "Ahmet Yılmaz", company_name: "Yılmaz PVC", email: "ahmet@example.com", phone: "5551234567", message: "Demo istiyorum." } }
    end

    assert_redirected_to new_demo_request_path
    follow_redirect!
    assert_match "Talebiniz alındı", response.body
  end

  test "missing required fields re-renders the form without sending mail" do
    assert_no_enqueued_emails do
      post demo_requests_path, params: { demo_request: { name: "", email: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "invalid email format is rejected" do
    assert_no_enqueued_emails do
      post demo_requests_path, params: { demo_request: { name: "Ahmet", email: "not-an-email" } }
    end

    assert_response :unprocessable_entity
  end

  test "new page renders for unauthenticated visitors" do
    get new_demo_request_path
    assert_response :success
  end
end
