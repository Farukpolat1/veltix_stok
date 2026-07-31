class ApplicationMailer < ActionMailer::Base
  # MAILER_FROM_ADDRESS, Resend'de doğrulanmış bir alan adına ait olmalı
  # (bkz. .env.example) — aksi halde Resend gönderimi reddeder.
  default from: "#{Veltix::PLATFORM_NAME} <#{ENV.fetch('MAILER_FROM_ADDRESS', 'no-reply@example.com')}>"
  layout "mailer"
end
