class CustomersController < ApplicationController
  SORT_COLUMNS = %w[code name il phone].freeze

  before_action :set_customer, only: %i[ show edit update destroy statement ]
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  def index
    authorize Customer
    @ils = Customer.where.not(il: [ nil, "" ]).distinct.order(:il).pluck(:il)
    @customers = paginate(filtered_and_sorted(policy_scope(Customer))).to_a
    @balances = Customer.balances_for(@customers)
  end

  def show
    @sales = @customer.sales.approved.includes(sale_lines: :product).order(sale_date: :desc)
    @pending_sales = @customer.sales.pending.order(created_at: :desc)
    @payments = @customer.customer_payments.order(paid_at: :desc)
    @payment = CustomerPayment.new(paid_at: Time.current)
  end

  def statement
    pdf = Pdf::CustomerStatementGenerator.call(customer: @customer)
    send_data pdf, filename: "cari-ekstre-#{@customer.code.presence || @customer.id}.pdf", type: "application/pdf", disposition: "inline"
  end

  def export_pdf
    authorize Customer, :index?
    customers = filtered_and_sorted(policy_scope(Customer)).to_a
    balances = Customer.balances_for(customers)

    rows = customers.map do |customer|
      [
        customer.code,
        customer.name,
        customer.phone,
        "#{ActiveSupport::NumberHelper.number_to_delimited(balances[customer.id].round(2), delimiter: ".", separator: ",")} ₺"
      ]
    end

    pdf = Pdf::ListReportGenerator.call(
      title: "Müşteriler",
      headers: [ "Kod", "Müşteri Adı", "Telefon", "Bakiye" ],
      rows: rows
    )
    send_data pdf, filename: "musteriler.pdf", type: "application/pdf", disposition: "inline"
  end

  def export_csv
    authorize Customer, :index?
    customers = filtered_and_sorted(policy_scope(Customer)).to_a
    balances = Customer.balances_for(customers)

    csv = CSV.generate(headers: true) do |csv|
      csv << [ "Kod", "Müşteri Adı", "Telefon", "İl", "Bakiye" ]
      customers.each do |customer|
        csv << [ customer.code, customer.name, customer.phone, customer.il, balances[customer.id].round(2) ]
      end
    end
    send_data csv, filename: "musteriler.csv", type: "text/csv", disposition: "attachment"
  end

  def new
    @customer = authorize Customer.new
  end

  # Vergi levhası/firma belgesi PDF'i yükleyip yeni müşteri formunu otomatik
  # doldurur — hiçbir şey kaydetmez, kullanıcı formu kontrol edip normal
  # create ile kaydeder.
  def extract_pdf
    authorize Customer, :create?
    file = params[:pdf_file]

    if file.blank?
      @customer = Customer.new
      @customer.errors.add(:base, "Lütfen bir PDF dosyası seçin.")
      return render :new, status: :unprocessable_entity
    end

    begin
      data = Invoices::CompanyDocumentExtractor.call(file.read)
      @customer = Customer.new(
        name: data[:name], tax_number: data[:tax_number], tax_office: data[:tax_office],
        address: data[:address], phone: data[:phone]
      )
      flash.now[:notice] = "Belgeden okunan bilgiler dolduruldu, kontrol edip kaydedin."
      render :new
    rescue Invoices::CompanyDocumentExtractor::ParseError => e
      @customer = Customer.new
      @customer.errors.add(:base, e.message)
      render :new, status: :unprocessable_entity
    end
  end

  def create
    @customer = authorize Customer.new(customer_params)

    if @customer.save
      redirect_to customers_path, notice: "Müşteri oluşturuldu."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @customer.update(customer_params)
      redirect_to customers_path, notice: "Müşteri güncellendi."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @customer.destroy
    redirect_to customers_path, notice: "Müşteri silindi."
  rescue ActiveRecord::DeleteRestrictionError
    redirect_to customers_path, alert: "Bu müşteriye bağlı satışlar var, silinemez."
  end

  private
    def set_customer
      @customer = authorize Customer.find(params[:id])
    end

    def customer_params
      params.expect(customer: [ :name, :tax_number, :tax_office, :phone, :address, :il, :code, :opening_balance ])
    end

    def filtered_and_sorted(scope)
      scope = scope.where("name ILIKE ?", "%#{params[:q]}%") if params[:q].present?
      scope = scope.where(il: params[:il]) if params[:il].present?

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
