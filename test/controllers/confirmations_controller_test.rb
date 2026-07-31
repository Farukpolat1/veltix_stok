require "test_helper"

class ConfirmationsControllerTest < ActionDispatch::IntegrationTest
  test "unconfirmed user cannot log in" do
    user = users(:one)
    user.update!(confirmed_at: nil)

    post session_path, params: { email_address: user.email_address, password: "password" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
    follow_redirect!
    assert_match "onaylamadınız", response.body
  end

  test "confirming via the emailed token allows the user to log in afterwards" do
    user = users(:one)
    user.update!(confirmed_at: nil)
    token = user.generate_token_for(:email_confirmation)

    get confirmation_path(token)
    assert_redirected_to new_session_path
    assert user.reload.confirmed?

    post session_path, params: { email_address: user.email_address, password: "password" }
    assert_redirected_to root_path
  end

  test "an invalid or expired confirmation token shows a friendly error" do
    get confirmation_path("not-a-real-token")
    assert_redirected_to new_session_path
    follow_redirect!
    assert_match "geçersiz", response.body
  end

  test "resending the confirmation email does not reveal whether the account exists" do
    assert_enqueued_email_with ConfirmationsMailer, :confirm, args: [ users(:one) ] do
      users(:one).update!(confirmed_at: nil)
      post confirmations_path, params: { email_address: users(:one).email_address }
    end
    assert_redirected_to new_session_path

    post confirmations_path, params: { email_address: "no-such-user@example.com" }
    assert_redirected_to new_session_path
  end
end
