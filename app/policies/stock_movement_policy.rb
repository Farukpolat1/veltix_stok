class StockMovementPolicy < ApplicationPolicy
  def index? = true
  def show? = true

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
