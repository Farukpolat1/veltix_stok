class ProductTemplatesController < ApplicationController
  before_action :set_product_template, only: %i[ edit update destroy lines ]
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  def index
    authorize ProductTemplate
    @product_templates = policy_scope(ProductTemplate).order(:name)
  end

  def new
    @product_template = authorize ProductTemplate.new
  end

  def create
    @product_template = authorize ProductTemplate.new(product_template_params)

    if @product_template.save
      redirect_to lines_product_template_path(@product_template), notice: "Şablon oluşturuldu, şimdi satırlarını ekleyin."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @product_template.update(product_template_params)
      redirect_to product_templates_path, notice: "Şablon güncellendi."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @product_template.destroy
    redirect_to product_templates_path, notice: "Şablon silindi."
  end

  # Şablonun malzeme satırlarını (kasa, kol, cam vb.) yönetme ekranı.
  def lines
    @categories = Category.order(:name)
    @template_line = TemplateLine.new
  end

  private
    def set_product_template
      @product_template = authorize ProductTemplate.find(params[:id])
    end

    def product_template_params
      params.expect(product_template: [ :name, :code, :description, :active ])
    end
end
