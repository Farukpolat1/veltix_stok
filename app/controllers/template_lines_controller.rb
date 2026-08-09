class TemplateLinesController < ApplicationController
  before_action :set_product_template
  after_action :verify_authorized

  def create
    authorize @product_template, :update?
    @line = @product_template.template_lines.new(template_line_params)
    @line.position = (@product_template.template_lines.maximum(:position) || 0) + 1

    if @line.save
      redirect_to lines_product_template_path(@product_template), notice: "Satır eklendi."
    else
      redirect_to lines_product_template_path(@product_template), alert: @line.errors.full_messages.to_sentence
    end
  end

  def destroy
    authorize @product_template, :update?
    @product_template.template_lines.find(params[:id]).destroy
    redirect_to lines_product_template_path(@product_template), notice: "Satır silindi."
  end

  private
    def set_product_template
      @product_template = ProductTemplate.find(params[:product_template_id])
    end

    def template_line_params
      params.expect(template_line: [ :category_id, :default_product_id, :label, :variable, :coefficient, :waste_factor, :offset_mm, :fixed_quantity ])
    end
end
