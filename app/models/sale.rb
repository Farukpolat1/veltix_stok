class Sale < ApplicationRecord
  acts_as_tenant(:company)
  belongs_to :customer
  belongs_to :created_by, class_name: "User"
  has_many :sale_lines, dependent: :destroy
  has_many_attached :source_pdfs
  has_one_attached :original_document

  enum :status, { pending: 0, approved: 1 }

  validates :sale_number, presence: true, uniqueness: { scope: :company_id }
  validates :sale_date, presence: true

  before_validation :generate_sale_number, on: :create

  # Hiç satırı yoksa ya da o an stokta olandan fazla miktar içeren bir satır
  # varsa (aradan zaman geçmiş, stok değişmiş olabilir; ya da PDF'ten yeni
  # eklenen bir ürünün henüz stoğu girilmemiş) satış onaylanamaz.
  def approvable?
    pending? && sale_lines.any? && insufficient_stock_lines.none?
  end

  def insufficient_stock_lines
    sale_lines.select(&:insufficient_stock?)
  end

  def approve!(user:)
    raise "Yetersiz stok var ya da hiç ürün eklenmemiş" unless approvable?

    transaction do
      sale_lines.each do |line|
        StockMovement.create!(
          product: line.product,
          source: line,
          direction: :out,
          quantity: line.quantity,
          occurred_at: Time.current,
          user: user
        )
      end
      update!(status: :approved)
    end
  end

  private
    def generate_sale_number
      return if sale_number.present?
      self.sale_number = "SAT-#{Time.current.strftime('%Y%m%d')}-#{SecureRandom.hex(3).upcase}"
    end
end
