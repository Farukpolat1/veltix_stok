class SalesController < ApplicationController
  SORT_COLUMNS = %w[sale_number sale_date status].freeze

  before_action :set_sale, only: %i[ destroy approve items receipt edit update ]
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  def index
    authorize Sale
    @sales = paginate(filtered_and_sorted(policy_scope(Sale)).includes(:customer))
  end

  def export_pdf
    authorize Sale, :index?
    sales = filtered_and_sorted(policy_scope(Sale)).includes(:customer, :sale_lines)

    rows = sales.map do |sale|
      [
        sale.sale_number,
        sale.external_order_number,
        sale.customer.name,
        sale.sale_date.strftime("%d.%m.%Y"),
        sale.approved? ? "Onaylandı" : "Beklemede",
        "#{ActiveSupport::NumberHelper.number_to_delimited(sale.sale_lines.sum(&:total_with_vat).round(2), delimiter: ".", separator: ",")} ₺"
      ]
    end

    pdf = Pdf::ListReportGenerator.call(
      title: "Satışlar",
      headers: [ "Satış No", "Sipariş No", "Müşteri", "Tarih", "Durum", "Toplam Tutar" ],
      rows: rows
    )
    send_data pdf, filename: "satislar.pdf", type: "application/pdf", disposition: "inline"
  end

  def export_csv
    authorize Sale, :index?
    sales = filtered_and_sorted(policy_scope(Sale)).includes(:customer, :sale_lines)

    csv = CSV.generate(headers: true) do |csv|
      csv << [ "Satış No", "Sipariş No", "Müşteri", "Tarih", "Durum", "Toplam Tutar" ]
      sales.each do |sale|
        csv << [
          sale.sale_number,
          sale.external_order_number,
          sale.customer.name,
          sale.sale_date.strftime("%d.%m.%Y"),
          sale.approved? ? "Onaylandı" : "Beklemede",
          sale.sale_lines.sum(&:total_with_vat).round(2)
        ]
      end
    end
    send_data csv, filename: "satislar.csv", type: "text/csv", disposition: "attachment"
  end

  # Müşteri seçilir/oluşturulur; ürünler bir sonraki ekranda (items) tek tek eklenir.
  def new
    @sale = authorize Sale.new(sale_date: Date.current), :create?
    @customers = Customer.order(:name)
  end

  def create
    authorize Sale, :create?
    @customers = Customer.order(:name)

    customer = resolve_customer
    unless customer
      @sale = Sale.new(sale_date: sale_params[:sale_date])
      @sale.errors.add(:base, "Müşteri seçin ya da yeni müşteri adı girin.")
      return render :new, status: :unprocessable_entity
    end

    @sale = Sale.new(sale_date: sale_params[:sale_date].presence || Date.current)
    @sale.customer = customer
    @sale.created_by = current_user

    if @sale.save
      redirect_to items_sale_path(@sale), notice: "Satış oluşturuldu. Şimdi ürünleri ekleyin."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def items
    @products = Product.order(:name)
    @categories = Category.order(:name)
    @product_templates = ProductTemplate.where(active: true).order(:name)
  end

  # Yanlış müşteri/tarih/sipariş no seçilmişse düzeltmek için — sadece
  # onaylanmamış satışlarda (bkz. SalePolicy#update?).
  def edit
    @customers = Customer.order(:name)
  end

  def update
    if @sale.update(sale_edit_params)
      redirect_to items_sale_path(@sale), notice: "Satış bilgileri güncellendi."
    else
      @customers = Customer.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  # Müşteri/satış zaten oluşturulmuş; buradan sadece PDF'teki ürün satırlarını
  # okuyup önizleme ekranında gösterir (bkz. items sayfası "PDF'ten Ürün Ekle").
  def import_lines_pdf
    @sale = Sale.find(params[:id])
    authorize @sale, :update?
    file = params.dig(:sale, :pdf_file)

    if file.blank?
      return redirect_to items_sale_path(@sale), alert: "Lütfen bir PDF dosyası seçin."
    end

    begin
      bytes = file.read
      @data = Invoices::SalePdfImporter.new(bytes).extract
      @pdf_blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(bytes), filename: file.original_filename.presence || "belge.pdf", content_type: "application/pdf")
      render :review_import_lines
    rescue Invoices::SalePdfImporter::ParseError => e
      redirect_to items_sale_path(@sale), alert: e.message
    end
  end

  def confirm_import_lines
    @sale = Sale.find(params[:id])
    authorize @sale, :update?
    raw = params.require(:sale).permit(:discount_rate, :pdf_blob_signed_id, lines: [ :name, :quantity, :unit, :unit_price, :vat_rate ])
    lines = (raw[:lines] || []).map { |line| line.to_h.symbolize_keys }

    begin
      importer = Invoices::SalePdfImporter.new(created_by: current_user)
      importer.persist_lines(@sale, lines, discount_rate: raw[:discount_rate])
      blob = ActiveStorage::Blob.find_signed(raw[:pdf_blob_signed_id])
      @sale.source_pdfs.attach(blob) if blob
      notice = "Satırlar eklendi."
      notice += " Yeni ürün olarak eklendi: #{importer.newly_created_products.join(', ')}" if importer.newly_created_products.any?
      redirect_to items_sale_path(@sale), notice: notice
    rescue Invoices::SalePdfImporter::ParseError, ActiveRecord::RecordInvalid => e
      @data = { lines: lines, discount_rate: raw[:discount_rate] }
      @pdf_blob = ActiveStorage::Blob.find_signed(raw[:pdf_blob_signed_id])
      flash.now[:alert] = "Eklenemedi: #{e.message}"
      render :review_import_lines, status: :unprocessable_entity
    end
  end

  # Şablondan (BOM) satır ekleme — kullanıcı bir ProductTemplate seçer, gerekli
  # ölçüleri girer ve önerilen (kol gibi çeşidi çok kategorilerde
  # değiştirilebilir) ürünleri onaylar. Boms::Calculator bkz. app/services/boms/calculator.rb.
  def new_from_template
    @sale = Sale.find(params[:id])
    authorize @sale, :update?
    @product_template = ProductTemplate.find(params[:product_template_id])
    template_lines = @product_template.template_lines
    @measurement_fields = template_lines.reject(&:fixed?).map(&:variable).uniq.map do |variable|
      [ TemplateLine::MEASUREMENT_KEYS.fetch(variable), TemplateLine::VARIABLE_LABELS.fetch(variable) ]
    end
    # hardware_schema_lookup satırları donanım kitini kanadın kendi ham
    # genişlik/yükseklik ölçüsüne göre seçiyor (bkz. HardwareResolver) —
    # diğer satırların kullandığı türetilmiş çevre/alan ölçülerinden ayrı.
    if template_lines.any?(&:hardware_schema_lookup?)
      @measurement_fields += [ [ :genislik_mm, "Kanat Genişliği (mm)" ], [ :yukseklik_mm, "Kanat Yüksekliği (mm)" ] ]
    end
    # Her satır için elle fiyat girmemek adına, o ürünün en son satıştaki
    # birim fiyatı varsayılan olarak dolduruluyor — kullanıcı sadece
    # değişmesi gerekeni değiştiriyor.
    @last_prices = template_lines.each_with_object({}) do |line, prices|
      next unless line.default_product
      last_line = SaleLine.where(product_id: line.default_product_id).order(created_at: :desc).first
      prices[line.id] = last_line&.unit_price
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to items_sale_path(@sale), alert: "Şablon bulunamadı."
  end

  def create_from_template
    @sale = Sale.find(params[:id])
    authorize @sale, :update?
    product_template = ProductTemplate.find(params[:product_template_id])
    measurements = params[:measurements]&.to_unsafe_h || {}
    overrides = (params[:product_ids]&.to_unsafe_h || {}).transform_values(&:presence).compact
    prices = params[:unit_prices]&.to_unsafe_h || {}
    vat_rates = params[:vat_rates]&.to_unsafe_h || {}

    results = Boms::Calculator.call(product_template, measurements: measurements, product_overrides: overrides)
    missing = results.select { |r| r.product.nil? }
    if missing.any?
      return redirect_to new_from_template_sale_path(@sale, product_template_id: product_template.id),
        alert: "Şu satırlar için ürün seçilmedi: #{missing.map { |r| r.template_line.label }.join(', ')}"
    end

    ActiveRecord::Base.transaction do
      results.each do |result|
        # hardware_schema_lookup satırları formda tek bir fiyat alanı olarak
        # gösterilmiyor (ölçüye göre kaç farklı gerçek ürün çıkacağı önceden
        # bilinmiyor) — bu satırlarda her parçanın kendi son satış fiyatı
        # kullanılır, diğer satırlarda formdan gelen fiyat kullanılır.
        unit_price =
          if result.template_line.hardware_schema_lookup?
            SaleLine.where(product_id: result.product.id).order(created_at: :desc).first&.unit_price || 0
          else
            prices[result.template_line.id.to_s].presence || 0
          end

        @sale.sale_lines.create!(
          product: result.product,
          quantity: result.quantity,
          unit_price: unit_price,
          vat_rate: vat_rates[result.template_line.id.to_s].presence || 20
        )
      end
    end

    redirect_to items_sale_path(@sale), notice: "\"#{product_template.name}\" şablonundan #{results.size} satır eklendi."
  rescue Boms::Calculator::MissingMeasurementError => e
    redirect_to new_from_template_sale_path(@sale, product_template_id: product_template.id), alert: e.message
  rescue ActiveRecord::RecordInvalid => e
    redirect_to items_sale_path(@sale), alert: "Eklenemedi: #{e.record.errors.full_messages.to_sentence}"
  end

  # Müşteriden gelen sipariş/ürün listesi PDF'i — Gemini ile okunur, hiçbir
  # şey kaydedilmez. Sonuç bir önizleme ekranında gösterilir; kullanıcı
  # düzenleyip onayladığında confirm_pdf gerçek kaydı oluşturur.
  def create_pdf
    authorize Sale, :create?
    @customers = Customer.order(:name)
    file = params.dig(:sale, :pdf_file)

    if file.blank?
      @sale = Sale.new
      @sale.errors.add(:base, "Lütfen bir PDF dosyası seçin.")
      return render :new, status: :unprocessable_entity
    end

    begin
      bytes = file.read
      @data = Invoices::SalePdfImporter.new(bytes).extract
      @pdf_blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(bytes), filename: file.original_filename.presence || "belge.pdf", content_type: "application/pdf")
      @matched_customer = find_matching_customer(@data[:customer])
      render :review_pdf
    rescue Invoices::SalePdfImporter::ParseError => e
      @sale = Sale.new
      @sale.errors.add(:base, e.message)
      render :new, status: :unprocessable_entity
    end
  end

  # Önizleme ekranında kullanıcı tarafından gözden geçirilmiş/düzeltilmiş veri
  # burada gerçekten kaydedilir.
  def confirm_pdf
    authorize Sale, :create?
    data = review_params
    pdf_blob = ActiveStorage::Blob.find_signed(params.dig(:sale, :pdf_blob_signed_id))

    begin
      importer = Invoices::SalePdfImporter.new(created_by: current_user)
      @sale = importer.persist(data)
      @sale.source_pdfs.attach(pdf_blob) if pdf_blob
      notice = "Satış oluşturuldu. Satırları kontrol edip tamamlayın."
      if importer.newly_created_products.any?
        notice += " Yeni ürün olarak eklendi (stoğu 0, onaylamadan önce stok girin): #{importer.newly_created_products.join(', ')}"
      end
      redirect_to items_sale_path(@sale), notice: notice
    rescue Invoices::SalePdfImporter::ParseError, ActiveRecord::RecordInvalid => e
      @data = data
      @pdf_blob = pdf_blob
      @matched_customer = find_matching_customer(data[:customer])
      flash.now[:alert] = "Kaydedilemedi: #{e.message}"
      render :review_pdf, status: :unprocessable_entity
    end
  end

  def receipt
    pdf = Pdf::ReceiptGenerator.call(
      title: "Satış Fişi",
      doc_number: @sale.sale_number,
      doc_date: @sale.sale_date,
      status_label: @sale.approved? ? "Onaylandı" : "Beklemede",
      counterparty_label: "Müşteri",
      counterparty_name: @sale.customer.name,
      lines: @sale.sale_lines.includes(:product).map { |line|
        {
          name: line.product.name,
          quantity: line.quantity,
          unit_label: line.product.unit_label,
          unit_price: line.unit_price,
          vat_rate: line.vat_rate,
          total_with_vat: line.total_with_vat
        }
      }
    )
    send_data pdf, filename: "satis-#{@sale.sale_number}.pdf", type: "application/pdf", disposition: "inline"
  end

  def approve
    lines = @sale.sale_lines.includes(:product).to_a
    customer = @sale.customer
    @sale.approve!(user: current_user)
    summary = lines.map { |l| "#{l.product.name}: stok şimdi #{l.product.reload.stock_quantity}" }.join(" · ")
    redirect_to sales_path, notice: "Satış onaylandı, stok güncellendi → #{summary} · #{customer.name} cari hesabına alacak eklendi, kalan bakiye: #{customer.reload.balance} ₺"
  rescue ActiveRecord::RecordInvalid, RuntimeError => e
    redirect_to items_sale_path(@sale), alert: "Onaylanamadı: #{e.message}"
  end

  def destroy
    @sale.destroy
    redirect_to sales_path, notice: "Satış silindi."
  end

  private
    def set_sale
      @sale = authorize Sale.find(params[:id])
    end

    def filtered_and_sorted(scope)
      scope = scope.joins(:customer).where("sale_number ILIKE ? OR customers.name ILIKE ?", "%#{params[:q]}%", "%#{params[:q]}%") if params[:q].present?
      scope = scope.where(status: params[:status]) if Sale.statuses.key?(params[:status])
      scope = scope.where("sale_date >= ?", Date.parse(params[:from])) if params[:from].present?
      scope = scope.where("sale_date <= ?", Date.parse(params[:to])) if params[:to].present?

      if SORT_COLUMNS.include?(params[:sort])
        scope.order(params[:sort] => sort_direction)
      else
        scope.order(created_at: :desc)
      end
    rescue ArgumentError
      scope.order(created_at: :desc)
    end

    def sort_direction
      params[:direction] == "desc" ? :desc : :asc
    end

    def sale_params
      params.fetch(:sale, {}).permit(:sale_date, :customer_id, :new_customer_name, :new_customer_tax_number)
    end

    def sale_edit_params
      params.expect(sale: [ :customer_id, :sale_date, :external_order_number ])
    end

    def resolve_customer
      if params.dig(:sale, :customer_id).present?
        Customer.find_by(id: params[:sale][:customer_id])
      elsif params.dig(:sale, :new_customer_name).present?
        Customer.create(
          name: params[:sale][:new_customer_name],
          tax_number: params[:sale][:new_customer_tax_number].presence
        )
      end
    end

    # Önizleme formundan dönen (kullanıcı tarafından düzenlenmiş olabilecek)
    # veriyi Invoices::SalePdfImporter#persist'in beklediği hash şekline sokar.
    def review_params
      raw = params.require(:sale).permit(
        :sale_date, :order_number, :discount_rate,
        customer: [ :code, :name, :tax_number, :tax_office, :address, :phone ],
        lines: [ :name, :quantity, :unit, :unit_price, :vat_rate ]
      )

      {
        sale_date: raw[:sale_date],
        order_number: raw[:order_number],
        discount_rate: raw[:discount_rate],
        customer: (raw[:customer] || {}).to_h.symbolize_keys,
        lines: (raw[:lines] || []).map { |line| line.to_h.symbolize_keys }
      }
    end

    # Önizleme ekranında müşterinin sistemde zaten var olup olmadığını
    # göstermek için — persist sırasında yapılan eşleştirmenin aynısı, ama
    # burada sadece bilgi amaçlı (kayıt oluşturmaz).
    def find_matching_customer(customer_data)
      return nil unless customer_data
      code = customer_data[:code].to_s.strip.presence
      return Customer.find_by(code: code) if code
      tax_number = customer_data[:tax_number].to_s.strip.presence
      return Customer.find_by(tax_number: tax_number) if tax_number
      name = customer_data[:name].to_s.strip.presence
      Customer.find_by("lower(name) = ?", name.downcase) if name
    end
end
