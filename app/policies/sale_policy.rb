class SalePolicy < ApplicationPolicy
  def index? = user.admin? || user.satis?
  def show? = user.admin? || user.satis?

  def create? = user.admin? || user.satis?
  def update? = (user.admin? || user.satis?) && record.pending?
  def edit? = update?
  def items? = user.admin? || user.satis?
  def receipt? = user.admin? || user.satis?
  def approve? = (user.admin? || user.satis?) && record.pending?
  def destroy? = user.admin? && record.pending?

  class Scope < Scope
    def resolve
      user.admin? || user.satis? ? scope.all : scope.none
    end
  end
end
