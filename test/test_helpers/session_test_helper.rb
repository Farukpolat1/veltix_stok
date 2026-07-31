module SessionTestHelper
  def sign_in_as(user)
    Current.session = user.sessions.create!
    # Gerçek istek döngüsünde ApplicationController#set_tenant_from_current_user
    # bunu otomatik yapar; testte bir isteğe kadar beklemeden (ör. fixture'sız
    # doğrudan Model.create! çağrıları için) hemen ayarlıyoruz.
    ActsAsTenant.current_tenant = user.company

    ActionDispatch::TestRequest.create.cookie_jar.tap do |cookie_jar|
      cookie_jar.signed[:session_id] = Current.session.id
      cookies["session_id"] = cookie_jar[:session_id]
    end
  end

  def sign_out
    Current.session&.destroy!
    cookies.delete("session_id")
    ActsAsTenant.current_tenant = nil
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include SessionTestHelper
end
