# Çok kiracılı (multi-tenant) yapının kiracısı — her firma bir Company. Tüm
# iş verisi modelleri (Customer, Product, Sale, ...) acts_as_tenant(:company)
# ile buna bağlanır ve otomatik olarak ActsAsTenant.current_tenant'a göre
# filtrelenir (bkz. app/controllers/application_controller.rb). PDF'lerdeki
# marka/künye bilgisi de artık burada tutulur (bkz. app/services/pdf/letterhead.rb).
#
# Bir firma silindiğinde (bkz. CompaniesController#destroy, sadece platform
# süper admin'i) o firmaya ait HER ŞEY kalıcı olarak silinir — bu yüzden
# aşağıdaki sıra önemli: her tablonun company_id'si veritabanında gerçek bir
# foreign key (bkz. db/schema.rb add_foreign_key), yani önce birbirine referans
# veren satırlar (ör. satışlar müşterilere, ürünler kategorilere), sonra
# referans verilenler, en son da kullanıcılar silinmeli (kullanıcı modeli
# kendi satış/fatura/stok hareketi kayıtları hâlâ varsa silinmeyi reddediyor).
class Company < ApplicationRecord
  has_many :sales, dependent: :destroy
  has_many :purchase_invoices, dependent: :destroy
  has_many :stock_movements, dependent: :destroy
  has_many :stock_adjustments, dependent: :destroy
  has_many :customer_payments, dependent: :destroy
  has_many :supplier_payments, dependent: :destroy
  has_many :supplier_product_mappings, dependent: :destroy
  has_many :product_templates, dependent: :destroy
  has_many :products, dependent: :destroy
  has_many :customers, dependent: :destroy
  has_many :suppliers, dependent: :destroy
  has_many :categories, dependent: :destroy
  has_many :category_option_groups, dependent: :destroy
  has_many :warehouses, dependent: :destroy
  has_many :support_requests, dependent: :destroy
  has_many :users, dependent: :destroy

  has_one_attached :logo

  validates :name, presence: true
  validates :tax_number, uniqueness: true, allow_blank: true
end
