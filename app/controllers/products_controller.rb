class ProductsController < ApplicationController
  SORT_COLUMNS = %w[code name unit stock_quantity min_stock_level].freeze

  before_action :set_product, only: %i[ edit update destroy ]
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  def index
    authorize Product
    # Filtreden bağımsız — üst kısımdaki grup dashboard'unun her zaman
    # toplam tabloyu göstermesi için (filtre uygulanınca sayılar değişmesin).
    base_scope = policy_scope(Product)
    @product_type_counts = base_scope.joins(:category).group("categories.product_type").count
    @low_stock_count = base_scope.where("stock_quantity <= min_stock_level").count
    @total_product_count = base_scope.count

    @products = paginate(filtered_and_sorted(base_scope))
  end

  def export_pdf
    authorize Product, :index?
    products = filtered_and_sorted(policy_scope(Product))

    rows = products.map do |product|
      [
        product.code,
        product.name,
        product.category.name,
        product.unit_label,
        product.stock_quantity.to_s,
        product.min_stock_level.to_s
      ]
    end

    pdf = Pdf::ListReportGenerator.call(
      title: "Ürünler",
      headers: [ "Kod", "Ad", "Kategori", "Birim", "Stok", "Min. Stok" ],
      rows: rows
    )
    send_data pdf, filename: "urunler.pdf", type: "application/pdf", disposition: "inline"
  end

  def export_csv
    authorize Product, :index?
    products = filtered_and_sorted(policy_scope(Product))

    csv = CSV.generate(headers: true) do |csv|
      csv << [ "Kod", "Ad", "Kategori", "Grup", "Birim", "Stok", "Min. Stok" ]
      products.each do |product|
        csv << [
          product.code,
          product.name,
          product.category.name,
          Category::PRODUCT_TYPE_LABELS[product.category.product_type],
          product.unit_label,
          product.stock_quantity,
          product.min_stock_level
        ]
      end
    end
    send_data csv, filename: "urunler.csv", type: "text/csv", disposition: "attachment"
  end

  def new
    @product = authorize Product.new
  end

  # Teknik föy/katalog sayfası PDF'i yükleyip yeni ürün formunu otomatik
  # doldurur — hiçbir şey kaydetmez, kullanıcı formu kontrol edip normal
  # create ile kaydeder.
  def extract_pdf
    authorize Product, :create?
    file = params[:pdf_file]

    if file.blank?
      @product = Product.new
      @product.errors.add(:base, "Lütfen bir PDF dosyası seçin.")
      return render :new, status: :unprocessable_entity
    end

    begin
      data = Products::PdfReader.call(file.read)
      category = Category.find_by("lower(name) = ?", data[:category_name].to_s.strip.downcase) if data[:category_name].present?
      @product = Product.new(name: data[:name], code: data[:code], unit: data[:unit], category: category)
      flash.now[:notice] = "Belgeden okunan bilgiler dolduruldu, kontrol edip kaydedin."
      render :new
    rescue Products::PdfReader::ParseError => e
      @product = Product.new
      @product.errors.add(:base, e.message)
      render :new, status: :unprocessable_entity
    end
  end

  def create
    @product = authorize Product.new(product_params)

    if @product.save
      redirect_to products_path, notice: "Ürün oluşturuldu."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @recent_purchases = PurchaseInvoiceLine
      .joins(:purchase_invoice)
      .where(product_id: @product.id)
      .includes(purchase_invoice: :supplier)
      .order("purchase_invoices.invoice_date DESC")
      .limit(10)
  end

  def update
    if @product.update(product_params)
      redirect_to products_path, notice: "Ürün güncellendi."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @product.destroy
    redirect_to products_path, notice: "Ürün silindi."
  rescue ActiveRecord::DeleteRestrictionError
    redirect_to products_path, alert: "Bu ürüne bağlı stok hareketleri var, silinemez."
  end

  private
    def set_product
      @product = authorize Product.find(params[:id])
    end

    def product_params
      params.expect(product: [ :code, :name, :category_id, :unit, :min_stock_level, :stock_quantity, :aliases_text, :color ])
    end

    def filtered_and_sorted(scope)
      scope = scope.includes(:category)
      scope = scope.where("products.name ILIKE ? OR products.code ILIKE ?", "%#{params[:q]}%", "%#{params[:q]}%") if params[:q].present?
      scope = scope.where("stock_quantity <= min_stock_level") if params[:low_stock].present?
      scope = scope.joins(:category).where(categories: { product_type: params[:product_type] }) if Category.product_types.key?(params[:product_type])

      if params[:sort] == "category"
        scope.joins(:category).order("categories.name #{sort_direction}")
      elsif SORT_COLUMNS.include?(params[:sort])
        scope.order(params[:sort] => sort_direction)
      else
        scope.order(:name)
      end
    end

    def sort_direction
      params[:direction] == "desc" ? :desc : :asc
    end
end
