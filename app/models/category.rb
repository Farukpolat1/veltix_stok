class Category < ApplicationRecord
  acts_as_tenant(:company)
  has_many :products, dependent: :restrict_with_error
  has_many :supplier_categories, dependent: :destroy
  has_many :suppliers, through: :supplier_categories

  enum :product_type, { profil: 0, aksesuar: 1, diger: 2 }, default: :diger

  # İş Özeti'ndeki "Beyaz/Renkli ..." kartlarının hangisine toplanacağı —
  # kategori bazında admin ekrandan atanır (bkz. category form), kod içine
  # gömülü bir kategori-adı listesi değil. nil = hiçbir karta dahil edilmez
  # (genel toplamlarda yine görünür, sadece renk kırılımına girmez).
  enum :dashboard_group, {
    profil_mtul: 0,
    pervaz: 1,
    lambri: 2,
    cam: 3,
    kapi_aksesuari: 4,
    aksesuar_cift_acilim: 5,
    aksesuar_tek_acilim: 6
  }, prefix: :dashboard_group

  DASHBOARD_GROUP_LABELS = {
    "profil_mtul" => "Mtül (Ana Profil)",
    "pervaz" => "Pervaz",
    "lambri" => "Lambri",
    "cam" => "Cam",
    "kapi_aksesuari" => "Kapı Aksesuarı",
    "aksesuar_cift_acilim" => "Aksesuar (Çift Açılım)",
    "aksesuar_tek_acilim" => "Aksesuar (Tek Açılım)"
  }.freeze

  DASHBOARD_GROUP_UNITS = {
    "profil_mtul" => "mtül",
    "pervaz" => "mtül",
    "lambri" => "mtül",
    "cam" => "m²",
    "kapi_aksesuari" => "adet",
    "aksesuar_cift_acilim" => "adet",
    "aksesuar_tek_acilim" => "adet"
  }.freeze

  PRODUCT_TYPE_LABELS = {
    "profil" => "Profil (PVC)",
    "aksesuar" => "Aksesuar (Donanım)",
    "diger" => "Diğer (Sac, Cam, Conta, Silikon vb.)"
  }.freeze

  validates :name, presence: true, uniqueness: { scope: :company_id }
  validates :code, uniqueness: { scope: :company_id }, allow_blank: true
  validates :color, presence: true, if: :profil?
  validates :accessory_type, presence: true, if: :aksesuar?

  # Marka/Renk/Alt Tür/Seri seçenekleri artık CategoryOption'da (yönetici
  # ekrandan düzenlenebilir) — bkz. app/models/category_option.rb ve
  # app/models/category_option_group.rb.
  def self.options_for(group_name)
    CategoryOptionGroup.find_by(name: group_name)&.category_options&.ordered&.pluck(:name) || []
  end

  def self.brand_options = options_for("Marka")
  def self.color_options = options_for("Renk")
  def self.accessory_type_options = options_for("Aksesuar Alt Türü")
  def self.series_options = options_for("Seri")

  # Yönetici Marka/Renk/Aksesuar Alt Türü/Seri'nin dışında kendi özel
  # gruplarını (ör. "Kalınlık") da açabilir — bunların seçilen değeri
  # custom_attributes (jsonb) içinde saklanır, sabit bir sütunları yoktur.
  def self.custom_option_groups
    CategoryOptionGroup.where.not(name: CategoryOptionGroup::CORE_NAMES).ordered
  end
end
