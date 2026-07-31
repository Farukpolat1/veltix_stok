class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    mail subject: "Şifrenizi sıfırlayın", to: user.email_address
  end
end
