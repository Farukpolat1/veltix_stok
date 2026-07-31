# Giriş yapmış herhangi bir kullanıcının (rolden bağımsız) bir talep/soru
# gönderebilmesi için — DemoRequestsController'ın aksine oturum açık olmalı,
# bu yüzden allow_unauthenticated_access YOK; kullanıcı adı/e-postası ve
# hangi firmadan gönderildiği formdan değil, oturumdan otomatik alınır.
#
# Ayrı bir sayfası yok — form her sayfada navbar'dan açılan bir modalda
# yaşıyor (bkz. shared/_support_request_modal), bu yüzden başarısızlıkta
# hangi sayfaya geri döneceğimizi bilemeyiz; redirect_back kullanılır.
class SupportRequestsController < ApplicationController
  def create
    @support_request = SupportRequest.new(support_request_params)

    if @support_request.valid?
      SupportRequestMailer.notify(
        "subject" => @support_request.subject,
        "message" => @support_request.message,
        "user_name" => current_user.display_name,
        "user_email" => current_user.email_address,
        "company_name" => current_company&.name
      ).deliver_later
      redirect_back fallback_location: root_path, notice: "Talebiniz alındı — en kısa sürede sizinle iletişime geçeceğiz."
    else
      redirect_back fallback_location: root_path, alert: @support_request.errors.full_messages.to_sentence
    end
  end

  private
    def support_request_params
      params.fetch(:support_request, {}).permit(:subject, :message)
    end
end
