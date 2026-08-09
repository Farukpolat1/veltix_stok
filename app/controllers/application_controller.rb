require "csv"

class ApplicationController < ActionController::Base
  # acts_as_tenant'a firmayı (tenant) kendi before_action'ımızla ayarlayacağımızı
  # söyler — bu satır sınıfın en üstünde olmalı (bkz. acts_as_tenant README).
  set_current_tenant_through_filter

  include Authentication
  include Pundit::Authorization
  include Paginatable
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  before_action :set_tenant_from_current_user
  before_action :load_recent_support_requests

  helper_method :current_user, :current_company, :impersonating?

  private
    def current_user
      Current.user
    end

    def current_company
      ActsAsTenant.current_tenant
    end

    # Süper admin, "Firmalar" ekranından başka bir firmaya "geçiş" yapmışsa
    # (bkz. CompaniesController#impersonate), o firmanın kimliğini session'da
    # tutuyoruz — kullanıcının KENDİ company_id'si (User#company) değişmiyor,
    # sadece iş verisinin hangi firmaya göre filtreleneceği (ActsAsTenant
    # current_tenant) geçici olarak değişiyor.
    def impersonating?
      Current.user&.super_admin? && session[:impersonated_company_id].present?
    end

    def effective_company
      return Current.user.company unless impersonating?
      Company.find_by(id: session[:impersonated_company_id]) || Current.user.company
    end

    # Bazı action'lar (ör. DashboardController#index, misafir/giriş yapmamış
    # ziyaretçilere de açık olduğu için allow_unauthenticated_access ile
    # require_authentication'ı atlıyor — bu durumda Current.session hiç
    # doldurulmamış olabilir, oturum açık olsa bile. resume_session burada
    # tekrar (idempotent) çağrılarak Current.user'ın, require_authentication
    # çalışmasa da doğru şekilde bilinmesi garanti edilir.
    def set_tenant_from_current_user
      resume_session
      set_current_tenant(effective_company) if Current.user
    end

    def user_not_authorized
      redirect_to root_path, alert: "Bu işlem için yetkiniz yok."
    end

    # Navbar'daki "Talep Oluştur" düğmesinin yanındaki modal (bkz.
    # shared/_support_requests_list_modal) her sayfada göründüğü için burada,
    # tüm authenticated action'lar için hazırlanır. Pundit'in izlenen
    # policy_scope helper'ı yerine Scope sınıfı doğrudan çağrılıyor — aksi
    # halde bu yardımcı sorgu, controller'ların KENDİ verify_policy_scoped
    # kontrolünü (ör. SalesController#index) yanlışlıkla "karşılanmış" gibi
    # gösterip asıl güvenlik ağını zayıflatırdı.
    def load_recent_support_requests
      return unless Current.user

      scope = SupportRequestPolicy::Scope.new(Current.user, SupportRequest).resolve.order(created_at: :desc)
      @recent_support_requests = Current.user.super_admin? ? scope.pending.limit(5) : scope.limit(5)
    end
end
