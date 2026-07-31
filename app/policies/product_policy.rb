class ProductPolicy < ApplicationPolicy
  def index? = true
  def show? = true

  def create? = user.admin? || user.depo?
  def update? = user.admin? || user.depo?
  def destroy? = user.admin?

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
