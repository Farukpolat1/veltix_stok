class SupportRequestMailer < ApplicationMailer
  # deliver_later ile kuyruğa alınabilmesi için serileştirilebilir bir Hash
  # alır (bkz. SupportRequestsController#create) — anahtarlar string.
  def notify(attrs)
    @message = attrs["message"]
    @user_name = attrs["user_name"]
    @user_email = attrs["user_email"]
    @company_name = attrs["company_name"]
    subject_text = attrs["subject"].presence || "Destek Talebi"

    mail(
      subject: "[#{@company_name}] #{subject_text}",
      to: Veltix::CONTACT_EMAIL,
      reply_to: @user_email
    )
  end
end
