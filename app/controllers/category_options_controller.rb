class CategoryOptionsController < ApplicationController
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  def index
    authorize CategoryOption
    @groups = policy_scope(CategoryOptionGroup).includes(:category_options).ordered
    @new_group = CategoryOptionGroup.new
    @new_option = CategoryOption.new
  end

  def create
    @option = authorize CategoryOption.new(option_params)

    if @option.save
      redirect_to category_options_path, notice: "Eklendi."
    else
      redirect_to category_options_path, alert: @option.errors.full_messages.to_sentence
    end
  end

  def destroy
    @option = authorize CategoryOption.find(params[:id])
    @option.destroy
    redirect_to category_options_path, notice: "Silindi."
  end

  private
    def option_params
      params.expect(category_option: [ :category_option_group_id, :name ])
    end
end
