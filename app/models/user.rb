class User < ApplicationRecord
  # Super Admin'in bir firmaya bağlı olma zorunluluğunu kaldırıyoruz (optional: true)
  belongs_to :company, optional: true

  has_secure_password
  has_many :sessions, dependent: :destroy

  has_many :purchase_invoices, foreign_key: :created_by_id, inverse_of: :created_by, dependent: :restrict_with_error
  has_many :sales, foreign_key: :created_by_id, inverse_of: :created_by, dependent: :restrict_with_error
  has_many :stock_movements, dependent: :restrict_with_error
  has_many :support_requests, dependent: :restrict_with_error

  enum :role, { admin: 0, depo: 1, satis: 2 }

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true

  # Platform süper admin'i (super_admin boolean sütunu) herhangi bir firmaya
  # bağlı olmak zorunda değil; diğer tüm kullanıcılar bir firmaya ait olmalı.
  validates :company_id, presence: true, unless: :super_admin?

  # has_secure_password zaten :password_reset için generates_token_for'u
  # otomatik tanımlıyor (bkz. ActiveModel::SecurePassword) — hesap onaylama
  # için aynı deseni kendimiz ekliyoruz. E-posta değişirse eski onay linki
  # geçersiz kalsın diye e-posta adresini token'ın bir parçası yapıyoruz.
  generates_token_for :email_confirmation, expires_in: 48.hours do
    email_address
  end

  def self.find_by_email_confirmation_token!(token)
    find_by_token_for!(:email_confirmation, token)
  end

  def display_name
    name.presence || email_address
  end

  def confirmed?
    confirmed_at.present?
  end

  def confirm!
    update!(confirmed_at: Time.current)
  end
end
