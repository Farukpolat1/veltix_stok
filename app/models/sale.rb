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

  # Onaylı bir satış silinirse (bkz. SalePolicy#destroy?, sadece admin/süper
  # admin), stoktan düşülmüş miktarların geri eklenmesi gerekir — aksi halde
  # StockMovement kaydı cascade ile silinir ama Product#stock_quantity yanlış
  # (eksik) kalır. Müşteri bakiyesi (Customer#balance) ise total_sold'u canlı
  # hesapladığı için satış satırları silinince kendiliğinden düzelir, ayrıca
  # bir şey yapmaya gerek yok.
  # prepend: true şart — aksi halde has_many :sale_lines, dependent: :destroy
  # kendi before_destroy'unu (satırları/stok hareketlerini siler) bu
  # callback'ten ÖNCE çalıştırır, biz stoğu geri eklemeye çalıştığımızda
  # sale_lines zaten silinmiş olur.
  before_destroy :reverse_stock_movements, if: :approved?, prepend: true

  # Hiç satırı yoksa satış onaylanamaz. Stok yetersizliği ise firmanın
  # Company#strict_stock_check ayarına bağlı — kapalıysa (ör. henüz tam
  # sayım yapılmamış yeni bir firma) stok 0/eksik olsa bile satış onaylanıp
  # stok negatife düşebilir; kapalı değilse (varsayılan) eskisi gibi engellenir.
  def approvable?
    return false unless pending? && sale_lines.any?
    return true unless company.strict_stock_check?

    insufficient_stock_lines.none?
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
    def reverse_stock_movements
      sale_lines.includes(:product, :stock_movement).each do |line|
        movement = line.stock_movement
        next unless movement
        delta = movement.in? ? -movement.quantity : movement.quantity
        line.product.increment!(:stock_quantity, delta)
      end
    end

    def generate_sale_number
      return if sale_number.present?
      self.sale_number = "SAT-#{Time.current.strftime('%Y%m%d')}-#{SecureRandom.hex(3).upcase}"
    end
end
