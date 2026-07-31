# Kayıtlı bir kullanıcıya değil, potansiyel bir müşteriye ait — hiçbir yerde
# saklanmaz, sadece DemoRequestMailer ile bildirilip atılır (bkz.
# DemoRequestsController).
class DemoRequest
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :name, :string
  attribute :company_name, :string
  attribute :email, :string
  attribute :phone, :string
  attribute :message, :string

  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
end
