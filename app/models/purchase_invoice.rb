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
end
