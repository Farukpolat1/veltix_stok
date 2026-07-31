class ConfirmationsMailer < ApplicationMailer
  def confirm(user)
    @user = user
    mail subject: "Hesabınızı onaylayın", to: user.email_address
  end
end
