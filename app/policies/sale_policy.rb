class SalePolicy < ApplicationPolicy
  def index? = user.admin? || user.satis?
  def show? = user.admin? || user.satis?

  def create? = user.admin? || user.satis?
  def update? = (user.admin? || user.satis?) && record.pending?
  def edit? = update?
  def items? = user.admin? || user.satis?
  def receipt? = user.admin? || user.satis?
  def approve? = (user.admin? || user.satis?) && record.pending?
  # Onaylı bir satışın silinmesi stoğu ve müşteri bakiyesini etkiler (bkz.
  # Sale#reverse_stock_movements) — bu yüzden beklemedeki satışların aksine
  # sadece admin/süper admin yapabilir, satış rolü yapamaz.
  def destroy? = user.admin? || user.super_admin?

  class Scope < Scope
    def resolve
      user.admin? || user.satis? ? scope.all : scope.none
    end
  end
end
