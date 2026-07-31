# Giriş yapmış bir kullanıcının, o an bağlı olduğu firmadan gönderdiği destek/
# talep mesajı — DemoRequest gibi hiçbir yerde saklanmaz, sadece
# SupportRequestMailer ile bildirilip atılır (bkz. SupportRequestsController).
# Kullanıcı adı/e-postası ve firma adı forma değil, oturumdan gelir.
class SupportRequest
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :subject, :string
  attribute :message, :string

  validates :message, presence: true
end
