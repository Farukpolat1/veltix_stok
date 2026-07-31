class CustomerPolicy < ApplicationPolicy
  def index? = user.admin? || user.satis?
  def show? = user.admin? || user.satis?

  def create? = user.admin? || user.satis?
  def update? = user.admin? || user.satis?
  def statement? = user.admin? || user.satis?
  def destroy? = user.admin?

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
