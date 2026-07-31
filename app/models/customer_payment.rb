class CustomerPayment < ApplicationRecord
  acts_as_tenant(:company)
  belongs_to :customer
  belongs_to :user
  has_one_attached :uploaded_pdfs
  has_one_attached :receipt

  enum :payment_method, { nakit: 0, banka_havalesi: 1, kredi_karti: 2, cek: 3, diger: 4 }

  PAYMENT_METHOD_LABELS = {
    "nakit" => "Nakit",
    "banka_havalesi" => "Banka Havalesi",
    "kredi_karti" => "Kredi Kartı",
    "cek" => "Çek",
    "diger" => "Diğer"
  }.freeze

  validates :amount, numericality: { greater_than: 0 }
  validates :paid_at, presence: true
end
