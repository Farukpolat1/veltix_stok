# Giriş yapmış bir kullanıcının, o an bağlı olduğu firmadan gönderdiği hata
# bildirimi / eksik özellik talebi — kalıcı olarak saklanır ki kullanıcı
# "Taleplerim" ekranında durumu ve verilen cevabı görebilsin (bkz.
# SupportRequestsController, SupportRequestMailer).
class SupportRequest < ApplicationRecord
  acts_as_tenant(:company)
  belongs_to :company
  belongs_to :user

  enum :category, { bug: 0, feature: 1, other: 2 }
  enum :status, { pending: 0, answered: 1 }

  validates :message, presence: true

  CATEGORY_LABELS = {
    "bug" => "Hata Bildirimi",
    "feature" => "Eksik Özellik / Talep",
    "other" => "Diğer"
  }.freeze

  def answer!(reply_text)
    update!(reply: reply_text, status: :answered, replied_at: Time.current)
  end
end
