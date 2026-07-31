class DemoRequestsController < ApplicationController
  layout "guest"
  allow_unauthenticated_access

  def new
    @demo_request = DemoRequest.new
  end

  def create
    @demo_request = DemoRequest.new(demo_request_params)

    if @demo_request.valid?
      DemoRequestMailer.notify(@demo_request.attributes).deliver_later
      redirect_to new_demo_request_path, notice: "Talebiniz alındı — en kısa sürede sizinle iletişime geçeceğiz."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def demo_request_params
      params.fetch(:demo_request, {}).permit(:name, :company_name, :email, :phone, :message)
    end
end
