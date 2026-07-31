class UserPolicy < ApplicationPolicy
  # User, acts_as_tenant ile scope'lanmıyor (bkz. app/models/user.rb) — bu
  # yüzden firma filtrelemesi burada elle yapılıyor. Kullanıcılar her zaman
  # o an GÖRÜNTÜLENEN firmaya göre kapsanır (ActsAsTenant.current_tenant —
  # süper admin başka bir firmaya "geçmişse" o firma, geçmemişse kendi
  # firması, bkz. CompaniesController#impersonate). Süper admin bile aynı
  # anda tüm firmaların kullanıcılarını karışık göremez; başka bir firmanın
  # kullanıcılarını yönetmek için önce o firmaya geçmesi gerekir.
  def index?   = user.super_admin? || user.admin?
  def create?  = user.super_admin? || user.admin?
  def update?  = user.super_admin? || (user.admin? && record.company_id == ActsAsTenant.current_tenant&.id)

  # Şirket yöneticisi kendi şirketindeki kişileri silebilir ama kendini silemez.
  def destroy? = user.super_admin? || (user.admin? && record != user && record.company_id == ActsAsTenant.current_tenant&.id)

  class Scope < Scope
    def resolve
      scope.where(company_id: ActsAsTenant.current_tenant&.id)
    end
  end
end
