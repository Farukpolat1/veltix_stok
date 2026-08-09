# Giriş yapmış herhangi bir kullanıcının (rolden bağımsız) hata bildirimi /
# eksik özellik talebi gönderebilmesi için — DemoRequestsController'ın
# aksine oturum açık olmalı, bu yüzden allow_unauthenticated_access YOK;
# kullanıcı adı/e-postası ve hangi firmadan gönderildiği formdan değil,
# oturumdan otomatik alınır.
#
# Oluşturma ayrı bir sayfası yok — form her sayfada navbar'dan açılan bir
# modalda yaşıyor (bkz. shared/_support_request_modal), bu yüzden create
# başarısızlığında hangi sayfaya geri döneceğimizi bilemeyiz; redirect_back
# kullanılır. "Taleplerim" listesi (index) ise gerçek bir sayfa — normal
# kullanıcı kendi taleplerini + verilen cevapları görür, süper admin tüm
# firmaların taleplerini görüp cevaplayabilir (bkz. SupportRequestPolicy).
class SupportRequestsController < ApplicationController
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  def index
    authorize SupportRequest
    @support_requests = policy_scope(SupportRequest).includes(:company, :user).order(created_at: :desc)
  end

  def create
    @support_request = authorize SupportRequest.new(support_request_params.merge(user: current_user))

    if @support_request.save
      SupportRequestMailer.notify(@support_request).deliver_later
      redirect_back fallback_location: root_path, notice: "Talebiniz alındı — en kısa sürede sizinle iletişime geçeceğiz."
    else
      redirect_back fallback_location: root_path, alert: @support_request.errors.full_messages.to_sentence
    end
  end

  def update
    @support_request = authorize ActsAsTenant.without_tenant { SupportRequest.find(params[:id]) }, :reply?
    @support_request.answer!(reply_params[:reply])
    redirect_to support_requests_path, notice: "Cevap gönderildi."
  end

  private
    def support_request_params
      params.fetch(:support_request, {}).permit(:category, :subject, :message)
    end

    def reply_params
      params.fetch(:support_request, {}).permit(:reply)
    end
end
