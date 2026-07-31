require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Veltix
  # Firma girişinden önce (giriş ekranı, sekme başlığı, e-posta gönderen adı)
  # kullanılan genel platform adı — hiçbir firmaya özel değil, çünkü o an
  # hangi firmanın giriş yaptığı henüz bilinmiyor. Her firmanın kendi adı/logosu
  # giriş yaptıktan sonra Company#name/#logo üzerinden gösterilir.
  PLATFORM_NAME = "Veltix"

  # Demo talepleri, destek talepleri gibi ziyaretçi/müşteri kaynaklı tüm
  # mailler bu adrese düşer (bkz. DemoRequestMailer, SupportRequestMailer).
  CONTACT_EMAIL = "Vertixmanagement@gmail.com"

  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    config.i18n.default_locale = :tr
    config.i18n.available_locales = [ :tr ]
    config.time_zone = "Istanbul"

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
