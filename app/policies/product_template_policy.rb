class ProductTemplatePolicy < ApplicationPolicy
  def index? = true
  def show? = true

  def create? = user.admin? || user.depo?
  def update? = user.admin? || user.depo?
  def destroy? = user.admin? || user.depo?

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
