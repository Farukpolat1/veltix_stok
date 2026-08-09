class SupportRequestPolicy < ApplicationPolicy
  def index? = true
  def create? = true

  # Sadece platform süper admin'i (Faruk) taleplere cevap verebilir.
  def reply? = user.super_admin?

  class Scope < Scope
    def resolve
      # Süper admin, destek talebi kutusunu (support inbox) tek bir yerden
      # yönetebilsin diye TÜM firmaların taleplerini görür — bu, diğer
      # modellerdeki (bkz. UserPolicy) "önce firmaya geç" kuralından bilinçli
      # bir istisna: talepler zaten doğrudan ona (platform sahibine) yönelik.
      # Normal kullanıcı sadece KENDİ gönderdiği talepleri görür.
      if user.super_admin?
        ActsAsTenant.without_tenant { scope.all }
      else
        scope.where(user_id: user.id)
      end
    end
  end
end
