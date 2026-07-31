# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  # Tüm temel işlemlerde varsayılan kural: "Sadece Super Admin ise izin ver"
  # Diğer roller için izinleri alt sınıflarda belirteceğiz.
  def index?
    user.super_admin?
  end

  def show?
    user.super_admin?
  end

  def create?
    user.super_admin?
  end

  def new?
    create?
  end

  def update?
    user.super_admin?
  end

  def edit?
    update?
  end

  def destroy?
    user.super_admin?
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      # acts_as_tenant zaten arka planda verileri firmaya (tenant) göre filtrelediği için
      # burada Pundit'in scope'unu ekstra daraltmaya gerek yok.
      scope.all
    end

    private

    attr_reader :user, :scope
  end
end
