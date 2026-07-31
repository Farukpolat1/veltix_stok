class SuppliersController < ApplicationController
  SORT_COLUMNS = %w[code name phone].freeze

  before_action :set_supplier, only: %i[ show edit update destroy statement ]
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  def index
    authorize Supplier
    @filter_categories = Category.order(:name)
    @suppliers = paginate(filtered_and_sorted(policy_scope(Supplier)).includes(:categories)).to_a
    @balances = Supplier.balances_for(@suppliers)
  end

  def show
    @purchase_invoices = @supplier.purchase_invoices.approved.includes(purchase_invoice_lines: :product).order(invoice_date: :desc)
    @pending_invoices = @supplier.purchase_invoices.pending.order(created_at: :desc)
    @payments = @supplier.supplier_payments.order(paid_at: :desc)
    @payment = SupplierPayment.new(paid_at: Time.current)
  end

  def statement
    pdf = Pdf::SupplierStatementGenerator.call(supplier: @supplier)
    send_data pdf, filename: "cari-ekstre-#{@supplier.code.presence || @supplier.id}.pdf", type: "application/pdf", disposition: "inline"
  end

  def export_pdf
    authorize Supplier, :index?
    suppliers = filtered_and_sorted(policy_scope(Supplier)).includes(:categories).to_a
    balances = Supplier.balances_for(suppliers)

    rows = suppliers.map do |supplier|
      [
        supplier.code,
        supplier.name,
        supplier.phone,
        "#{ActiveSupport::NumberHelper.number_to_delimited(balances[supplier.id].round(2), delimiter: ".", separator: ",")} ₺"
      ]
    end

    pdf = Pdf::ListReportGenerator.call(
      title: "Tedarikçiler",
      headers: [ "Kod", "Firma Adı", "Telefon", "Bakiye" ],
      rows: rows
    )
    send_data pdf, filename: "tedarikciler.pdf", type: "application/pdf", disposition: "inline"
  end

  def export_csv
    authorize Supplier, :index?
    suppliers = filtered_and_sorted(policy_scope(Supplier)).includes(:categories).to_a
    balances = Supplier.balances_for(suppliers)

    csv = CSV.generate(headers: true) do |csv|
      csv << [ "Kod", "Firma Adı", "Telefon", "Kategoriler", "Bakiye" ]
      suppliers.each do |supplier|
        csv << [ supplier.code, supplier.name, supplier.phone, supplier.categories.map(&:name).join(", "), balances[supplier.id].round(2) ]
      end
    end
    send_data csv, filename: "tedarikciler.csv", type: "text/csv", disposition: "attachment"
  end

  def new
    @supplier = authorize Supplier.new
    @categories = Category.order(:name)
  end

  # Vergi levhası/firma belgesi PDF'i yükleyip yeni tedarikçi formunu otomatik
  # doldurur — hiçbir şey kaydetmez, kullanıcı formu kontrol edip normal
  # create ile kaydeder.
  def extract_pdf
    authorize Supplier, :create?
    @categories = Category.order(:name)
    file = params[:pdf_file]

    if file.blank?
      @supplier = Supplier.new
      @supplier.errors.add(:base, "Lütfen bir PDF dosyası seçin.")
      return render :new, status: :unprocessable_entity
    end

    begin
      data = Invoices::CompanyDocumentExtractor.call(file.read)
      @supplier = Supplier.new(
        name: data[:name], tax_number: data[:tax_number], tax_office: data[:tax_office],
        address: data[:address], phone: data[:phone]
      )
      flash.now[:notice] = "Belgeden okunan bilgiler dolduruldu, kontrol edip kaydedin."
      render :new
    rescue Invoices::CompanyDocumentExtractor::ParseError => e
      @supplier = Supplier.new
      @supplier.errors.add(:base, e.message)
      render :new, status: :unprocessable_entity
    end
  end

  def create
    @supplier = authorize Supplier.new(supplier_params)

    if @supplier.save
      redirect_to suppliers_path, notice: "Tedarikçi oluşturuldu."
    else
      @categories = Category.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @categories = Category.order(:name)
  end

  def update
    if @supplier.update(supplier_params)
      redirect_to suppliers_path, notice: "Tedarikçi güncellendi."
    else
      @categories = Category.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @supplier.destroy
    redirect_to suppliers_path, notice: "Tedarikçi silindi."
  rescue ActiveRecord::DeleteRestrictionError
    redirect_to suppliers_path, alert: "Bu tedarikçiye bağlı faturalar var, silinemez."
  end

  private
    def set_supplier
      @supplier = authorize Supplier.find(params[:id])
    end

    def supplier_params
      params.expect(supplier: [ :name, :tax_number, :tax_office, :phone, :address, :code, :opening_balance, category_ids: [] ])
    end

    def filtered_and_sorted(scope)
      scope = scope.where("name ILIKE ?", "%#{params[:q]}%") if params[:q].present?
      scope = scope.joins(:supplier_categories).where(supplier_categories: { category_id: params[:category_id] }) if params[:category_id].present?

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
