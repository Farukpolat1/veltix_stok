class StockMovementsController < ApplicationController
  PER_PAGE = 50

  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  def index
    authorize StockMovement
    base = base_filtered(policy_scope(StockMovement))
    @direction_counts = base.group(:direction).count
    scope = apply_direction(base).order(occurred_at: :desc)
    @stock_movements = paginate(scope.preload(:product, :user, :source), per_page: PER_PAGE)

    today_scope = policy_scope(StockMovement).where(occurred_at: Time.current.all_day)
    @today_movement_count = today_scope.count
    @today_stock_in = today_scope.where(direction: :in).sum(:quantity)
    @today_stock_out = today_scope.where(direction: :out).sum(:quantity)
  end

  def export_pdf
    authorize StockMovement, :index?
    movements = filtered(policy_scope(StockMovement)).preload(:product, :user, :source).order(occurred_at: :desc)

    rows = movements.map do |movement|
      [
        movement.occurred_at.strftime("%d.%m.%Y %H:%M"),
        movement.product.name,
        movement.in? ? "Giriş" : "Çıkış",
        movement.quantity.to_s,
        movement.source_label,
        movement.user.display_name
      ]
    end

    pdf = Pdf::ListReportGenerator.call(
      title: "Stok Hareketleri",
      headers: [ "Tarih", "Ürün", "Yön", "Miktar", "Kaynak", "Kullanıcı" ],
      rows: rows
    )
    send_data pdf, filename: "stok-hareketleri.pdf", type: "application/pdf", disposition: "inline"
  end

  def export_csv
    authorize StockMovement, :index?
    movements = filtered(policy_scope(StockMovement)).preload(:product, :user, :source).order(occurred_at: :desc)

    csv = CSV.generate(headers: true) do |csv|
      csv << [ "Tarih", "Ürün", "Yön", "Miktar", "Kaynak", "Kullanıcı" ]
      movements.each do |movement|
        csv << [
          movement.occurred_at.strftime("%d.%m.%Y %H:%M"),
          movement.product.name,
          movement.in? ? "Giriş" : "Çıkış",
          movement.quantity,
          movement.source_label,
          movement.user.display_name
        ]
      end
    end
    send_data csv, filename: "stok-hareketleri.csv", type: "text/csv", disposition: "attachment"
  end

  private
    def filtered(scope)
      apply_direction(base_filtered(scope))
    end

    def base_filtered(scope)
      scope = scope.joins(:product).where("products.name ILIKE ?", "%#{params[:q]}%") if params[:q].present?
      scope = scope.where("occurred_at >= ?", Date.parse(params[:from]).beginning_of_day) if params[:from].present?
      scope = scope.where("occurred_at <= ?", Date.parse(params[:to]).end_of_day) if params[:to].present?
      scope
    rescue ArgumentError
      scope
    end

    def apply_direction(scope)
      params[:direction].present? ? scope.where(direction: params[:direction]) : scope
    end
end
