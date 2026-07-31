class SupplierPolicy < ApplicationPolicy
  def index? = user.admin? || user.depo?
  def show? = user.admin? || user.depo?
  def statement? = user.admin? || user.depo?

  def create? = user.admin? || user.depo?
  def update? = user.admin? || user.depo?
  def destroy? = user.admin?

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
