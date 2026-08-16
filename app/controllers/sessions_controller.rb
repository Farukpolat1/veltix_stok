class SessionsController < ApplicationController
  layout "guest", only: :new
  allow_unauthenticated_access only: %i[ new create ]
  # store: bilinçli olarak süreç-içi bellek (varsayılan Rails.cache/Solid
  # Cache DEĞİL) — giriş, hiçbir şart altında Solid Cache tablosunun
  # varlığına/erişilebilirliğine bağımlı olmamalı; o tablo bir sorun
  # yaşarsa (ör. henüz migrate edilmemiş) kimse giriş yapamaz hale gelirdi.
  rate_limit to: 10, within: 3.minutes, only: :create, store: ActiveSupport::Cache::MemoryStore.new,
    with: -> { redirect_to new_session_path, alert: "Çok fazla deneme yapıldı. Lütfen birkaç dakika sonra tekrar deneyin." }

  def new
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      if user.confirmed?
        start_new_session_for user
        redirect_to after_authentication_url
      else
        redirect_to new_session_path, alert: "Hesabınızı henüz onaylamadınız. Lütfen e-postanızı kontrol edin."
      end
    else
      redirect_to new_session_path, alert: "E-posta veya şifre hatalı."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
