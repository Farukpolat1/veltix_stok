class DemoRequestMailer < ApplicationMailer
  # deliver_later ile kuyruğa alınabilmesi için PORO nesnesi yerine
  # serileştirilebilir bir Hash alır (bkz. DemoRequestsController#create).
  def notify(attributes)
    @demo_request = DemoRequest.new(attributes)
    mail(
      subject: "Yeni Demo Talebi: #{@demo_request.company_name.presence || @demo_request.name}",
      to: Veltix::CONTACT_EMAIL,
      reply_to: @demo_request.email
    )
  end
end
