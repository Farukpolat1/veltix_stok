require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Yüklenen fatura PDF'leri/ürün görselleri container'ın kendi diskinde değil
  # Cloudflare R2'de (bkz. config/storage.yml, R2_* env değişkenleri) tutulur
  # — aksi halde her deploy/restart'ta container'ın diskiyle birlikte
  # kaybolabilirler.
  config.active_storage.service = :cloud

  # Render, SSL'i kendi reverse proxy'sinde sonlandırıp uygulamaya düz HTTP
  # olarak iletiyor — bu ikisi açık olmadan hem oturum çerezleri güvensiz
  # (secure: false) kalır hem de mail linkleri yanlışlıkla http:// üretebilir.
  config.assume_ssl = true
  config.force_ssl = true

  # Health check endpoint'i (Render'ın "/up" ile canlılık kontrolü yaptığı
  # yer) https yönlendirmesinden muaf tutulmalı, aksi halde 301 dönüp
  # Render'ı yanıltabilir.
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  config.action_mailer.raise_delivery_errors = true

  # Set host to be used by links generated in mailer templates — gerçek
  # alan adınızı ENV["APP_HOST"] ile ayarlayın (bkz. .env.example).
  config.action_mailer.default_url_options = { host: ENV.fetch("APP_HOST", "example.com") }

  # Resend'in SMTP relay'i (resend.com/docs) — RESEND_API_KEY ortam
  # değişkeni zorunlu, aksi halde uygulama gerçek e-posta gönderemez.
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: "smtp.resend.com",
    port: 587,
    user_name: "resend",
    password: ENV.fetch("RESEND_API_KEY", nil),
    authentication: :plain,
    enable_starttls_auto: true
  }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  #
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
