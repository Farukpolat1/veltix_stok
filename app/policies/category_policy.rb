class CategoryPolicy < ApplicationPolicy
  def index? = true
  def show? = true

  def create? = user.admin?
  def update? = user.admin?
  def destroy? = user.admin?

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
