# Liste sayfaları için basit, bağımlılıksız sayfalandırma (bkz.
# StockMovementsController/StockAdjustmentsController'da zaten kullanılan
# @page/@total_pages/@total_count deseni — burada tekilleştirildi ki her
# controller aynı mantığı elle tekrarlamasın).
module Paginatable
  extend ActiveSupport::Concern

  DEFAULT_PER_PAGE = 20

  def paginate(scope, per_page: DEFAULT_PER_PAGE)
    @total_count = scope.count
    @total_pages = [ (@total_count / per_page.to_f).ceil, 1 ].max
    @page = params[:page].to_i.clamp(1, Float::INFINITY).to_i
    @page = @total_pages if @page > @total_pages

    scope.limit(per_page).offset((@page - 1) * per_page)
  end
end
