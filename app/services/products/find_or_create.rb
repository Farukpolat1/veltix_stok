module Products
  # Fatura/satış kalemi eklerken kullanıcı bir ürün adı yazar; bu isim mevcut bir
  # ürünle eşleşiyorsa o ürün kullanılır, eşleşmiyorsa (kategori/birim verilmişse)
  # yeni bir ürün otomatik oluşturulur. Böylece kullanıcı "mevcut ürünü seç" ile
  # "yeni ürün ekle" arasında ayrı bir ekrana geçmek zorunda kalmaz.
  class FindOrCreate
    FALLBACK_CATEGORY_NAME = "Sınıflandırılmamış".freeze

    class MissingCategoryError < StandardError; end

    # fallback_to_default: true ise kategori verilmediğinde hata fırlatmak yerine
    # "Sınıflandırılmamış" kategorisini kullanır (örn. toplu/otomatik ekleme akışlarında).
    def self.call(name:, category_id: nil, unit: nil, code: nil, fallback_to_default: false)
      new(name: name, category_id: category_id, unit: unit, code: code, fallback_to_default: fallback_to_default).call
    end

    def initialize(name:, category_id: nil, unit: nil, code: nil, fallback_to_default: false)
      @name = name.to_s.strip
      @category_id = category_id
      @unit = unit
      @code = code.to_s.strip.presence
      @fallback_to_default = fallback_to_default
    end

    def call
      raise ArgumentError, "Ürün adı boş olamaz" if @name.blank?

      existing = Product.find_by("lower(name) = ?", @name.downcase) ||
        Product.where("EXISTS (SELECT 1 FROM unnest(aliases) a WHERE lower(a) = ?)", @name.downcase).first
      return existing if existing

      category_id = @category_id.presence || (@fallback_to_default && default_category.id)
      raise MissingCategoryError, "\"#{@name}\" adında bir ürün bulunamadı. Yeni ürün oluşturmak için kategori seçin." if category_id.blank?

      Product.create!(name: @name, code: @code, category_id: category_id, unit: @unit.presence || "adet")
    end

    private
      def default_category
        Category.find_or_create_by!(name: FALLBACK_CATEGORY_NAME)
      end
  end
end
