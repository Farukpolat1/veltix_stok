# SENTRY_DSN ortam değişkeni boşsa (local/test) Sentry SDK sessizce hiçbir
# şey yapmaz — bu yüzden initializer'ı koşulsuz çalıştırmak güvenli.
# DSN'i sentry.io üzerinden proje açıp almanız gerekiyor (bkz. .env.example).
Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.enabled_environments = %w[production]
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]

  # Performans izleme — düşük bir oranla açık, maliyeti/gürültüyü artırmasın.
  config.traces_sample_rate = 0.1

  # Firma/kullanıcı verisi içeren istek gövdelerini Sentry'ye göndermez.
  config.send_default_pii = false
end
