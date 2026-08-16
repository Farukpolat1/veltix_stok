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
    #
    # product_id: PDF önizleme ekranında kullanıcı "bu isim aslında şu mevcut
    # ürün" diye bir öneriyi seçtiyse geçirilir — isim eşleşmesi hiç denenmez,
    # doğrudan o ürün kullanılır ve okunan isim (zaten alias/ad değilse) o
    # ürüne alias olarak eklenir; böylece aynı isim bir sonraki belgede otomatik
    # eşleşir, kullanıcıya bir daha sorulmaz.
    def self.call(name:, category_id: nil, unit: nil, code: nil, fallback_to_default: false, product_id: nil)
      new(name: name, category_id: category_id, unit: unit, code: code, fallback_to_default: fallback_to_default, product_id: product_id).call
    end

    def initialize(name:, category_id: nil, unit: nil, code: nil, fallback_to_default: false, product_id: nil)
      @name = name.to_s.strip
      @category_id = category_id
      @unit = unit
      @code = code.to_s.strip.presence
      @fallback_to_default = fallback_to_default
      @product_id = product_id.presence
    end

    def call
      raise ArgumentError, "Ürün adı boş olamaz" if @name.blank?

      if @product_id
        product = Product.find(@product_id)
        product.update!(aliases: (Array(product.aliases) + [ @name ]).uniq) unless product.name_or_alias_matches?(@name)
        return product
      end

      existing = Product.match_by_name_or_alias(@name)
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
