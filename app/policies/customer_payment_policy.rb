class CustomerPaymentPolicy < ApplicationPolicy
  def create? = user.admin? || user.satis?
  def destroy? = user.admin?
  def parse_pdf? = create?

  class Scope < Scope
    def resolve
      user.admin? || user.satis? ? scope.all : scope.none
    end
  end
end
