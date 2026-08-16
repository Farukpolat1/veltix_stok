class ProductTemplatePolicy < ApplicationPolicy
  def index? = true
  def show? = true

  def create? = user.admin? || user.depo?
  def update? = user.admin? || user.depo?
  def destroy? = user.admin? || user.depo?
  # "Satırları Yönet" ekranı (ProductTemplatesController#lines) — Pundit,
  # action_name'den "lines?" adında bir policy metodu arıyor, bu olmadan
  # NoMethodError ile patlıyordu.
  def lines? = update?

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
