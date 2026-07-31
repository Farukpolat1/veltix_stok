class PurchaseInvoiceItemsController < ApplicationController
  before_action :set_purchase_invoice
  after_action :verify_authorized

  def create
    authorize @purchase_invoice, :update?
    product = Products::FindOrCreate.call(
      name: item_params[:product_name],
      category_id: item_params[:category_id],
      unit: item_params[:unit],
      code: item_params[:product_code]
    )

    @purchase_invoice.purchase_invoice_lines.create!(
      product: product,
      external_code: product.code,
      external_name: product.name,
      quantity: item_params[:quantity],
      unit_price: item_params[:unit_price],
      vat_rate: item_params[:vat_rate].presence || 20
    )
    redirect_to items_purchase_invoice_path(@purchase_invoice), notice: "Ürün eklendi."
  rescue Products::FindOrCreate::MissingCategoryError, ArgumentError => e
    redirect_to items_purchase_invoice_path(@purchase_invoice), alert: e.message
  rescue ActiveRecord::RecordInvalid => e
    redirect_to items_purchase_invoice_path(@purchase_invoice), alert: "Eklenemedi: #{e.record.errors.full_messages.join(', ')}"
  end

  def destroy
    authorize @purchase_invoice, :update?
    @purchase_invoice.purchase_invoice_lines.find(params[:id]).destroy
    redirect_to items_purchase_invoice_path(@purchase_invoice), notice: "Satır silindi."
  end

  private
    def set_purchase_invoice
      @purchase_invoice = PurchaseInvoice.find(params[:purchase_invoice_id])
    end

    def item_params
      params.expect(purchase_invoice_line: [ :product_name, :product_code, :category_id, :unit, :quantity, :unit_price, :vat_rate ])
    end
end
