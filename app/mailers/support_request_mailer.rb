class SupportRequestMailer < ApplicationMailer
  def notify(support_request)
    @support_request = support_request

    mail(
      subject: "[#{support_request.company.name}] #{support_request.subject.presence || SupportRequest::CATEGORY_LABELS[support_request.category]}",
      to: Veltix::CONTACT_EMAIL,
      reply_to: support_request.user.email_address
    )
  end
end
