class ConfirmationsController < ApplicationController
  layout "guest", only: :new
  allow_unauthenticated_access
  # store: bkz. sessions_controller.rb'deki aynı satırın yorumu — Solid
  # Cache'e bağımlı olmasın diye süreç-içi bellek kullanıyoruz.
  rate_limit to: 10, within: 3.minutes, only: :create, store: ActiveSupport::Cache::MemoryStore.new,
    with: -> { redirect_to new_confirmation_path, alert: "Çok fazla deneme yapıldı. Lütfen birkaç dakika sonra tekrar deneyin." }

  def new
  end

  # Onay e-postasını tekrar gönderir — hesap var mı yok mu belli etmemek
  # için (bkz. PasswordsController#create) her durumda aynı mesaj döner.
  def create
    user = User.find_by(email_address: params[:email_address])
    ConfirmationsMailer.confirm(user).deliver_later if user && !user.confirmed?

    redirect_to new_session_path, notice: "Bu e-posta adresine kayıtlı, onay bekleyen bir hesap varsa, onay bağlantısı yeniden gönderildi."
  end

  def show
    user = User.find_by_email_confirmation_token!(params[:token])
    user.confirm!
    redirect_to new_session_path, notice: "Hesabınız onaylandı, artık giriş yapabilirsiniz."
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to new_session_path, alert: "Onay bağlantısı geçersiz veya süresi dolmuş."
  end
end
