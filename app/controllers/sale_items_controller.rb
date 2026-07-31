class SaleItemsController < ApplicationController
  before_action :set_sale
  after_action :verify_authorized

  def create
    authorize @sale, :update?
    product = Products::FindOrCreate.call(
      name: item_params[:product_name],
      category_id: item_params[:category_id],
      unit: item_params[:unit],
      code: item_params[:product_code]
    )

    @sale.sale_lines.create!(
      product: product,
      quantity: item_params[:quantity],
      unit_price: item_params[:unit_price],
      vat_rate: item_params[:vat_rate].presence || 20
    )
    redirect_to items_sale_path(@sale), notice: "Ürün eklendi."
  rescue Products::FindOrCreate::MissingCategoryError, ArgumentError => e
    redirect_to items_sale_path(@sale), alert: e.message
  rescue ActiveRecord::RecordInvalid => e
    redirect_to items_sale_path(@sale), alert: "Eklenemedi: #{e.record.errors.full_messages.join(', ')}"
  end

  def destroy
    authorize @sale, :update?
    @sale.sale_lines.find(params[:id]).destroy
    redirect_to items_sale_path(@sale), notice: "Satır silindi."
  end

  private
    def set_sale
      @sale = Sale.find(params[:sale_id])
    end

    def item_params
      params.expect(sale_line: [ :product_name, :product_code, :category_id, :unit, :quantity, :unit_price, :vat_rate ])
    end
end
