class SupplierPaymentPolicy < ApplicationPolicy
  def create? = user.admin? || user.depo?
  def destroy? = user.admin?
  def parse_pdf? = create?

  class Scope < Scope
    def resolve
      user.admin? || user.depo? ? scope.all : scope.none
    end
  end
end
