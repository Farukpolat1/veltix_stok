class CategoriesController < ApplicationController
  SORT_COLUMNS = %w[code name product_type series brand].freeze

  before_action :set_category, only: %i[ edit update destroy ]
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  def index
    authorize Category
    base_scope = policy_scope(Category)
    @product_type_counts = base_scope.group(:product_type).count
    @total_category_count = base_scope.count

    @categories = paginate(filtered_and_sorted(base_scope))
  end

  def export_pdf
    authorize Category, :index?
    categories = filtered_and_sorted(policy_scope(Category))

    rows = categories.map do |category|
      [
        category.code,
        category.name,
        Category::PRODUCT_TYPE_LABELS[category.product_type],
        category.profil? ? category.color : (category.aksesuar? ? category.accessory_type : nil),
        category.brand
      ]
    end

    pdf = Pdf::ListReportGenerator.call(
      title: "Kategoriler",
      headers: [ "Kod", "Ad", "Çeşit", "Renk / Alt Tür", "Marka" ],
      rows: rows
    )
    send_data pdf, filename: "kategoriler.pdf", type: "application/pdf", disposition: "inline"
  end

  def export_csv
    authorize Category, :index?
    categories = filtered_and_sorted(policy_scope(Category))

    csv = CSV.generate(headers: true) do |csv|
      csv << [ "Kod", "Ad", "Grup", "Seri", "Renk / Alt Tür", "Marka" ]
      categories.each do |category|
        csv << [
          category.code,
          category.name,
          Category::PRODUCT_TYPE_LABELS[category.product_type],
          category.series,
          category.profil? ? category.color : (category.aksesuar? ? category.accessory_type : nil),
          category.brand
        ]
      end
    end
    send_data csv, filename: "kategoriler.csv", type: "text/csv", disposition: "attachment"
  end

  def new_pdf
    @category = authorize Category.new, :create?
  end

  # Tedarikçi katalog/fiyat listesi PDF'i — Gemini API ile okunup kategori ve
  # ürünler otomatik oluşturulur (stok sıfır, gerçek sayım ayrıca girilir).
  def create_pdf
    authorize Category, :create?
    file = params.dig(:category, :pdf_file)

    if file.blank?
      @category = Category.new
      @category.errors.add(:base, "Lütfen bir PDF dosyası seçin.")
      return render :new_pdf, status: :unprocessable_entity
    end

    begin
      result = Catalogs::PdfImporter.new(file.read).call
      notice = "Katalog PDF'ten okundu: #{result[:categories].size} yeni kategori, #{result[:products].size} yeni ürün oluşturuldu (stok 0, Mal Kabul/Stok Sayımı ile girin)."
      redirect_to categories_path, notice: notice
    rescue Catalogs::PdfImporter::ParseError => e
      @category = Category.new
      @category.errors.add(:base, e.message)
      render :new_pdf, status: :unprocessable_entity
    end
  end

  def new
    @category = authorize Category.new
  end

  def create
    @category = authorize Category.new(category_params)

    if @category.save
      redirect_to categories_path, notice: "Kategori oluşturuldu."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @category.update(category_params)
      redirect_to categories_path, notice: "Kategori güncellendi."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @category.destroy
    redirect_to categories_path, notice: "Kategori silindi."
  rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError
    redirect_to categories_path, alert: "Bu kategoriye bağlı ürünler var, silinemez."
  end

  private
    def set_category
      @category = authorize Category.find(params[:id])
    end

    def category_params
      params.expect(category: [ :name, :product_type, :code, :color, :accessory_type, :brand, :series, custom_attributes: {} ])
    end

    def filtered_and_sorted(scope)
      scope = scope.where("name ILIKE ?", "%#{params[:q]}%") if params[:q].present?
      scope = scope.where(product_type: params[:product_type]) if Category.product_types.key?(params[:product_type])

      if SORT_COLUMNS.include?(params[:sort])
        scope.order(params[:sort] => sort_direction)
      else
        scope.order(:name)
      end
    end

    def sort_direction
      params[:direction] == "desc" ? :desc : :asc
    end
end
