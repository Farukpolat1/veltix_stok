class CategoryOptionGroupsController < ApplicationController
  after_action :verify_authorized

  def create
    @group = authorize CategoryOptionGroup.new(group_params)

    if @group.save
      redirect_to category_options_path, notice: "Yeni özellik grubu eklendi. Şimdi altına değerler ekleyebilirsiniz."
    else
      redirect_to category_options_path, alert: @group.errors.full_messages.to_sentence
    end
  end

  def destroy
    @group = authorize CategoryOptionGroup.find(params[:id])

    if @group.core?
      redirect_to category_options_path, alert: "Marka, Renk, Aksesuar Alt Türü ve Seri silinemez — bunlar kategorilerde doğrudan kullanılıyor."
    else
      @group.destroy
      redirect_to category_options_path, notice: "Özellik grubu silindi."
    end
  end

  private
    def group_params
      params.expect(category_option_group: [ :name ])
    end
end
