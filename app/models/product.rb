class Product < ApplicationRecord
  acts_as_tenant(:company)
  belongs_to :category
  has_many :supplier_product_mappings, dependent: :destroy
  has_many :stock_movements, dependent: :restrict_with_error

  enum :unit, { adet: 0, koli: 1, kutu: 2, mt: 3, mtul: 4, paket: 5, m2: 6 }

  UNIT_LABELS = { "adet" => "Adet", "koli" => "Koli", "kutu" => "Kutu", "mt" => "Metre", "mtul" => "Metretül", "paket" => "Paket", "m2" => "m²" }.freeze

  validates :code, presence: true, uniqueness: { scope: :company_id }
  validates :name, presence: true
  validates :min_stock_level, :stock_quantity, numericality: { greater_than_or_equal_to: 0 }

  before_validation :generate_code, if: -> { code.blank? }

  def low_stock?
    stock_quantity <= min_stock_level
  end

  def unit_label
    UNIT_LABELS[unit]
  end

  # İş Özeti'ndeki "Beyaz / Renkli" kartları için kaba kırılım — profil
  # ürünlerinde color ada göre otomatik dolduruldu (bkz. backfill), aksesuar/
  # camda elle girilir. color boşsa hiçbir karta girmez (nil).
  def color_group
    return nil if color.blank?
    color.strip.casecmp?("beyaz") ? "Beyaz" : "Renkli"
  end

  # Alış faturasında/kataloğunda ve müşteri siparişinde aynı ürün farklı
  # isimle geçebiliyor (ör. "Ege Lambri 200" alışta, "Kapı Lambrisi" satış
  # siparişinde) — Products::FindOrCreate ve arama bu alternatif isimlerden
  # de eşleştirsin diye eklendi. Form'dan virgülle ayrılmış tek metin olarak
  # girilir, burada diziye çevrilir.
  def aliases_text
    Array(aliases).join(", ")
  end

  def aliases_text=(value)
    self.aliases = value.to_s.split(",").map { |s| s.strip.presence }.compact
  end

  def name_or_alias_matches?(text)
    return false if text.blank?
    name.to_s.casecmp?(text.to_s.strip) || Array(aliases).any? { |a| a.casecmp?(text.to_s.strip) }
  end

  # Ad veya alternatif isimlerden (aliases) BİREBİR eşleşme — Products::FindOrCreate
  # önce bunu dener, bulursa yeni ürün açmaz.
  def self.match_by_name_or_alias(name)
    return nil if name.blank?
    find_by("lower(name) = ?", name.downcase) ||
      where("EXISTS (SELECT 1 FROM unnest(aliases) a WHERE lower(a) = ?)", name.downcase).first
  end

  # Birebir eşleşme yoksa, PDF önizleme ekranında kullanıcıya "bunu mu
  # demiştiniz?" diye sormak için pg_trgm ile benzer isimli ürünleri bulur
  # (ör. alışta "Ege Lambri 200 (Beyaz)", satışta "Kapı Lambrisi" — ikisi de
  # trigram benzerliğiyle önerilebilir; kullanıcı seçerse alias otomatik eklenir).
  def self.suggest_matches(text, limit: 5, threshold: 0.2)
    return none if text.blank?
    where("similarity(name, ?) > ?", text, threshold)
      .order(Arel.sql("similarity(name, #{connection.quote(text)}) DESC"))
      .limit(limit)
  rescue ActiveRecord::StatementInvalid
    # pg_trgm bazı ortamlarda (izin kısıtlı yönetilen Postgres) etkinleştirilemeyebilir
    # (bkz. ilgili migration'daki rescue) — bu durumda öneri sessizce boş döner,
    # sistem "yeni ürün oluşturulacak" davranışına düşer, hiçbir yeri kilitlemez.
    none
  end

  private
    def generate_code
      base = name.to_s.parameterize(separator: "-").upcase.first(20).sub(/-+\z/, "")
      base = "URUN" if base.blank?
      candidate = base
      n = 1
      while Product.where(code: candidate).where.not(id: id).exists?
        n += 1
        candidate = "#{base}-#{n}"
      end
      self.code = candidate
    end
end
