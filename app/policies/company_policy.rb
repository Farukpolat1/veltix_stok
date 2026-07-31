class CompanyPolicy < ApplicationPolicy
  # update?/edit? — kendi firmasını düzenleyen bir admin (bkz.
  # CompanySettingsController, current_company) YA DA herhangi bir firmayı
  # düzenleyen platform süper admin'i (bkz. CompaniesController).
  def update? = user.super_admin? || (user.admin? && record == user.company)
  def edit?   = update?

  # index?/create?/destroy? — sadece platform sahibi (super_admin): yeni
  # firma (müşteri) ekleme/listeleme/silme ekranı; sıradan firma admin'leri
  # bunlara erişemez.
  def index?       = user.super_admin?
  def create?      = user.super_admin?
  def destroy?     = user.super_admin?
  def impersonate? = user.super_admin?

  class Scope < Scope
    def resolve
      user.super_admin? ? scope.all : scope.none
    end
  end
end
