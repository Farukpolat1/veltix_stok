class CategoryOptionGroupPolicy < ApplicationPolicy
  def index? = true
  def create? = user.admin?
  def destroy? = user.admin?

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
