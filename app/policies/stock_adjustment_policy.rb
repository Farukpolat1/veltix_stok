class StockAdjustmentPolicy < ApplicationPolicy
  def index? = user.admin? || user.depo?
  def create? = user.admin? || user.depo?

  class Scope < Scope
    def resolve
      user.admin? || user.depo? ? scope.all : scope.none
    end
  end
end
