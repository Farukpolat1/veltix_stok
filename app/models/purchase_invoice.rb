class PurchaseInvoice < ApplicationRecord
  acts_as_tenant(:company)
  belongs_to :supplier
  belongs_to :created_by, class_name: "User"
  has_many :purchase_invoice_lines, dependent: :destroy
  accepts_nested_attributes_for :purchase_invoice_lines
  has_many_attached :source_pdfs
  has_one_attached :original_document

  enum :status, { pending: 0, approved: 1 }

  validates :invoice_number, presence: true, uniqueness: { scope: :supplier_id, message: "bu tedarikçi için zaten kayıtlı — aynı fatura tekrar eklenmiş olabilir" }
  validates :invoice_date, presence: true
  validates :ubl_uuid, uniqueness: { scope: :company_id }, allow_blank: true

  # Onaylı bir fatura silinirse (bkz. PurchaseInvoicePolicy#destroy?, sadece
  # admin/süper admin), stoğa eklenmiş miktarların geri alınması gerekir —
  # aksi halde StockMovement kaydı cascade ile silinir ama
  # Product#stock_quantity yanlış (fazla) kalır. Tedarikçi bakiyesi
  # (Supplier#balance) ise total_purchased'ı canlı hesapladığı için fatura
  # satırları silinince kendiliğinden düzelir, ayrıca bir şey yapmaya gerek yok.
  # prepend: true şart — aksi halde has_many :purchase_invoice_lines,
  # dependent: :destroy kendi before_destroy'unu (satırları/stok
  # hareketlerini siler) bu callback'ten ÖNCE çalıştırır, biz stoğu geri
  # almaya çalıştığımızda purchase_invoice_lines zaten silinmiş olur.
  before_destroy :reverse_stock_movements, if: :approved?, prepend: true

  # Hiç satırı yoksa ya da eşleşmemiş (product_id boş) satır varsa fatura onaylanamaz.
  def approvable?
    pending? && purchase_invoice_lines.any? && purchase_invoice_lines.where(product_id: nil).none?
  end

  # XML/PDF içe aktarma satırları ham tedarikçi verisiyle (external_code/name) gelir ve
  # ürünle eşleşene kadar product_id boş olabilir — bu satırlar eşleştirme ekranına
  # (edit) yönlendirilmeli. Elle girilen satırlarda product_id her zaman baştan doludur.
  def needs_line_matching?
    ubl_uuid.present? || purchase_invoice_lines.where(product_id: nil).exists?
  end

  def approve!(user:)
    raise "Eşleştirilmemiş satırlar var" unless approvable?

    transaction do
      purchase_invoice_lines.each do |line|
        StockMovement.create!(
          product: line.product,
          source: line,
          direction: :in,
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
      purchase_invoice_lines.includes(:product, :stock_movement).each do |line|
        movement = line.stock_movement
        next unless movement && line.product
        delta = movement.in? ? -movement.quantity : movement.quantity
        line.product.increment!(:stock_quantity, delta)
      end
    end
end
