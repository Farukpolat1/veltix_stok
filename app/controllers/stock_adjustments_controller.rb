class StockAdjustmentsController < ApplicationController
  PER_PAGE = 50

  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  def index
    authorize StockAdjustment
    scope = filtered(policy_scope(StockAdjustment)).order(created_at: :desc)
    @stock_adjustments = paginate(scope.includes(:product, :user), per_page: PER_PAGE)

    today_scope = policy_scope(StockAdjustment).where(adjusted_at: Time.current.all_day)
    @today_adjustment_count = today_scope.count
    @today_increase_total = today_scope.sum("GREATEST(quantity_after - quantity_before, 0)")
    @today_decrease_total = today_scope.sum("GREATEST(quantity_before - quantity_after, 0)")
  end

  def export_pdf
    authorize StockAdjustment, :index?
    adjustments = filtered(policy_scope(StockAdjustment)).includes(:product, :user).order(created_at: :desc)

    rows = adjustments.map do |adj|
      [
        adj.adjusted_at.strftime("%d.%m.%Y %H:%M"),
        adj.product.name,
        adj.quantity_before.to_s,
        adj.quantity_after.to_s,
        "#{adj.difference.positive? ? "+" : ""}#{adj.difference}",
        adj.reason,
        adj.user.display_name
      ]
    end

    pdf = Pdf::ListReportGenerator.call(
      title: "Stok Düzeltme Geçmişi",
      headers: [ "Tarih", "Ürün", "Önce", "Sonra", "Fark", "Sebep", "Kullanıcı" ],
      rows: rows
    )
    send_data pdf, filename: "stok-duzeltme-gecmisi.pdf", type: "application/pdf", disposition: "inline"
  end

  def export_csv
    authorize StockAdjustment, :index?
    adjustments = filtered(policy_scope(StockAdjustment)).includes(:product, :user).order(created_at: :desc)

    csv = CSV.generate(headers: true) do |csv|
      csv << [ "Tarih", "Ürün", "Önce", "Sonra", "Fark", "Sebep", "Kullanıcı" ]
      adjustments.each do |adj|
        csv << [
          adj.adjusted_at.strftime("%d.%m.%Y %H:%M"),
          adj.product.name,
          adj.quantity_before,
          adj.quantity_after,
          adj.difference,
          adj.reason,
          adj.user.display_name
        ]
      end
    end
    send_data csv, filename: "stok-duzeltme-gecmisi.csv", type: "text/csv", disposition: "attachment"
  end

  def new
    @stock_adjustment = authorize StockAdjustment.new(product_id: params[:product_id])
    @products = Product.order(:name)
  end

  def create
    product = Product.find(adjustment_params[:product_id])
    @stock_adjustment = authorize StockAdjustment.new(
      product: product,
      user: current_user,
      quantity_before: product.stock_quantity,
      quantity_after: adjustment_params[:quantity_after],
      reason: adjustment_params[:reason],
      adjusted_at: Time.current
    )

    if @stock_adjustment.save
      redirect_to stock_adjustments_path, notice: "Stok düzeltmesi kaydedildi: #{product.name} #{@stock_adjustment.quantity_before} → #{@stock_adjustment.quantity_after}"
    else
      @products = Product.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  private
    def adjustment_params
      params.expect(stock_adjustment: [ :product_id, :quantity_after, :reason ])
    end

    def filtered(scope)
      scope = scope.joins(:product).where("products.name ILIKE ?", "%#{params[:q]}%") if params[:q].present?
      scope = scope.where("adjusted_at >= ?", Date.parse(params[:from]).beginning_of_day) if params[:from].present?
      scope = scope.where("adjusted_at <= ?", Date.parse(params[:to]).end_of_day) if params[:to].present?
      scope
    rescue ArgumentError
      scope
    end
end
