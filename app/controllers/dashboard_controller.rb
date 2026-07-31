class DashboardController < ApplicationController
  layout :dashboard_layout
  allow_unauthenticated_access only: :index

  PERIODS = {
    "day" => ->(t) { t.all_day },
    "week" => ->(t) { t.all_week },
    "month" => ->(t) { t.all_month },
    "year" => ->(t) { t.all_year }
  }.freeze
  PERIOD_LABELS = { "day" => "Bugün", "week" => "Bu Hafta", "month" => "Bu Ay", "year" => "Bu Yıl" }.freeze
  DAY_NAMES = %w[Paz Pzt Sal Çar Per Cum Cmt].freeze

  # Giriş yapmamış ziyaretçi için "Anasayfa" — tanıtım içeriği (bkz.
  # guest_home.html.erb + layouts/guest); giriş yapmış kullanıcı için normal
  # işletme panosu (admin: index, diğer roller: workspace).
  def index
    return render :guest_home unless authenticated?

    @low_stock_products = Product.where("stock_quantity <= min_stock_level").order(:name)

    if params[:stock_query].present?
      q = params[:stock_query]
      @stock_query = q
      @stock_results = Product.where("code ILIKE ? OR name ILIKE ?", "%#{q}%", "%#{q}%").order(:name)
    end

    if current_user.admin?
      load_home_glance
      render :index
    else
      load_workspace
      render :workspace
    end
  end

  # İş Özeti — satış/alış/tahsilat toplamları. Anasayfa sade kalsın diye
  # ayrı bir sayfaya taşındı, Yönetim menüsünden erişilir. Sadece admin.
  def summary
    return redirect_to root_path, alert: "Yetkiniz yok" unless current_user.admin?
    load_admin_summary
  end

  # Patronun "bu ay ne oldu" diye indirebileceği özet PDF — anasayfadaki İş
  # Özeti ile aynı hesaplama mantığı (compute_period_stats), seçilen ay için.
  def monthly_report
    return redirect_to root_path, alert: "Yetkiniz yok" unless current_user.admin?

    month = parse_month_param(params[:month])
    range = month.beginning_of_month.beginning_of_day..month.end_of_month.end_of_day
    stats = compute_period_stats(range)

    pdf = Pdf::MonthlyReportGenerator.call(month: month, stats: stats)
    send_data pdf, filename: "aylik-rapor-#{month.strftime('%Y-%m')}.pdf", type: "application/pdf", disposition: "attachment"
  end

  private
    def dashboard_layout
      authenticated? ? "application" : "guest"
    end

    def load_admin_summary
      @period = PERIODS.key?(params[:period]) ? params[:period] : "day"
      range = PERIODS[@period].call(Time.current)
      stats = compute_period_stats(range)

      @pending_purchase_invoices_count = stats[:pending_purchase_invoices]
      @pending_sales_count = stats[:pending_sales]
      @period_stock_in = stats[:stock_in]
      @period_stock_out = stats[:stock_out]
      @period_purchase_count = stats[:purchase_count]
      @period_purchase_total = stats[:purchase_total]
      @period_purchase_mtul = stats[:purchase_mtul]
      @period_purchase_m2 = stats[:purchase_m2]
      @period_sale_count = stats[:sale_count]
      @period_sale_total = stats[:sale_total]
      @period_sale_mtul = stats[:sale_mtul]
      @period_sale_m2 = stats[:sale_m2]
      @period_customer_payments_total = stats[:customer_payments]
      @period_supplier_payments_total = stats[:supplier_payments]
    end

    def load_workspace
      @pending_purchase_invoices = PurchaseInvoice.pending.includes(:supplier).order(created_at: :desc).limit(10) if current_user.depo?
      @pending_sales = Sale.pending.includes(:customer).order(created_at: :desc).limit(10) if current_user.satis?
    end

    # Anasayfa üst kısmındaki küçük özet rozetleri, KPI kartları ve son 7 gün
    # stok grafiği.
    def load_home_glance
      @today_sale_count = Sale.where(created_at: Time.current.all_day).count
      @pending_sales_count = Sale.pending.count
      @pending_purchase_invoices_count = PurchaseInvoice.pending.count
      @low_stock_count = @low_stock_products.size
      @stock_chart_days = last_7_days_stock_chart

      @today_revenue = revenue_for(Time.current.all_day)
      @revenue_trend_percent = trend_percent(@today_revenue, revenue_for(1.day.ago.all_day))
      @monthly_stock_movement_total = StockMovement.where(occurred_at: Time.current.all_month).sum(:quantity)
    end

    # Onaylanmış satışların (KDV dahil) toplam tutarı — approve edildiği an
    # updated_at güncellendiği için "bugün onaylanan" bunun üzerinden bulunur
    # (bkz. compute_period_stats'taki aynı desen).
    def revenue_for(range)
      SaleLine.joins(:sale).where(sales: { status: :approved, updated_at: range })
              .sum("sale_lines.quantity * sale_lines.unit_price * (1 + sale_lines.vat_rate / 100)")
    end

    def trend_percent(today, yesterday)
      return nil if yesterday.zero?
      ((today - yesterday) / yesterday * 100).round(1)
    end

    def last_7_days_stock_chart
      today = Date.current
      6.downto(0).map do |offset|
        date = today - offset.days
        range = date.all_day
        {
          label: DAY_NAMES[date.wday],
          stock_in: StockMovement.where(occurred_at: range, direction: :in).sum(:quantity),
          stock_out: StockMovement.where(occurred_at: range, direction: :out).sum(:quantity)
        }
      end
    end

    def compute_period_stats(range)
      approved_purchase_lines = PurchaseInvoiceLine.joins(:purchase_invoice, :product).where(purchase_invoices: { status: :approved, updated_at: range })
      approved_sale_lines = SaleLine.joins(:sale, :product).where(sales: { status: :approved, updated_at: range })

      {
        stock_in: StockMovement.where(occurred_at: range, direction: :in).sum(:quantity),
        stock_out: StockMovement.where(occurred_at: range, direction: :out).sum(:quantity),
        # Pencere/pimapen sektöründe iş hacmi "adet" değil, alınan/satılan metretül (profil) ve m² (cam) ile ölçülür.
        purchase_count: PurchaseInvoice.approved.where(updated_at: range).count,
        purchase_total: approved_purchase_lines.sum("purchase_invoice_lines.quantity * purchase_invoice_lines.unit_price * (1 + purchase_invoice_lines.vat_rate / 100)"),
        purchase_mtul: approved_purchase_lines.where(products: { unit: :mtul }).sum("purchase_invoice_lines.quantity"),
        purchase_m2: approved_purchase_lines.where(products: { unit: :m2 }).sum("purchase_invoice_lines.quantity"),
        sale_count: Sale.approved.where(updated_at: range).count,
        sale_total: approved_sale_lines.sum("sale_lines.quantity * sale_lines.unit_price * (1 + sale_lines.vat_rate / 100)"),
        sale_mtul: approved_sale_lines.where(products: { unit: :mtul }).sum("sale_lines.quantity"),
        sale_m2: approved_sale_lines.where(products: { unit: :m2 }).sum("sale_lines.quantity"),
        customer_payments: CustomerPayment.where(paid_at: range).sum(:amount),
        supplier_payments: SupplierPayment.where(paid_at: range).sum(:amount),
        pending_purchase_invoices: PurchaseInvoice.pending.count,
        pending_sales: Sale.pending.count
      }
    end

    def parse_month_param(value)
      return Date.current.beginning_of_month if value.blank?
      Date.strptime(value, "%Y-%m")
    rescue ArgumentError
      Date.current.beginning_of_month
    end
end
