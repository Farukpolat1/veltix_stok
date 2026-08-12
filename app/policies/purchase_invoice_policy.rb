class PurchaseInvoicePolicy < ApplicationPolicy
  def index? = user.admin? || user.depo?
  def show? = user.admin? || user.depo?

  def create? = user.admin? || user.depo?
  def edit? = user.admin? || user.depo?
  def items? = user.admin? || user.depo?
  def receipt? = user.admin? || user.depo?
  def update? = (user.admin? || user.depo?) && record.pending?
  def approve? = (user.admin? || user.depo?) && record.pending?
  # Onaylı bir faturanın silinmesi stoğu ve tedarikçi bakiyesini etkiler
  # (bkz. PurchaseInvoice#reverse_stock_movements) — bu yüzden beklemedeki
  # faturaların aksine sadece admin/süper admin yapabilir, depo rolü yapamaz.
  def destroy? = user.admin? || user.super_admin?

  class Scope < Scope
    def resolve
      user.admin? || user.depo? ? scope.all : scope.none
    end
  end
end
