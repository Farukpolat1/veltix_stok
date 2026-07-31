class PurchaseInvoicePolicy < ApplicationPolicy
  def index? = user.admin? || user.depo?
  def show? = user.admin? || user.depo?

  def create? = user.admin? || user.depo?
  def edit? = user.admin? || user.depo?
  def items? = user.admin? || user.depo?
  def receipt? = user.admin? || user.depo?
  def update? = (user.admin? || user.depo?) && record.pending?
  def approve? = (user.admin? || user.depo?) && record.pending?
  def destroy? = user.admin? && record.pending?

  class Scope < Scope
    def resolve
      user.admin? || user.depo? ? scope.all : scope.none
    end
  end
end
