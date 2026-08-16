# Render deploy'unda tüm veritabanları (primary/cache/queue/cable) TEK bir
# fiziksel Postgres'i paylaşıyor (bkz. config/database.yml — hepsi aynı
# DATABASE_URL'i kullanıyor). Bu, "db:prepare"i kırıyor: primary'nin
# db:prepare'i çalışıp kendi schema_migrations'ını oluşturduğunda, cache/
# queue/cable AYNI fiziksel veritabanına baktığı için (ayrı bir veritabanı
# değiller, sadece ayrı bir Rails bağlantı adı) o schema_migrations'ı GÖRÜP
# "bu veritabanı zaten hazır" sanıyor ve solid_cache_entries/solid_queue_jobs/
# solid_cable_messages tablolarını HİÇ oluşturmuyor — db:schema:load'ı hiç
# çağırmıyor. Sonuç: Rails.cache/Solid Queue/Solid Cable kullanan HER YER
# (ör. rate_limit, Action Cable, arka plan işleri) "relation ... does not
# exist" ile çöküyor, halbuki `bundle exec rake db:prepare` "başarılı"
# görünüyor (hata fırlatmıyor, sadece sessizce eksik bırakıyor).
#
# Bu görev bin/docker-entrypoint içinde db:prepare'den HEMEN SONRA çalışır;
# sadece ilgili tablo GERÇEKTEN yoksa o veritabanının şemasını yükler
# (idempotent — tablo zaten varsa dokunmaz, hiçbir veri kaybı riski yok).
namespace :db do
  desc "cache/queue/cable tabloları (paylaşılan tek veritabanı kurulumunda) eksikse oluşturur"
  task ensure_shared_databases_prepared: :environment do
    next unless Rails.env.production?

    { cache: "solid_cache_entries", queue: "solid_queue_jobs", cable: "solid_cable_messages" }.each do |db_name, marker_table|
      config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: db_name.to_s)
      next unless config

      ActiveRecord::Tasks::DatabaseTasks.with_temporary_pool_for_each(name: db_name.to_s) do |pool|
        pool.with_connection do |connection|
          if connection.table_exists?(marker_table)
            puts "db:ensure_shared_databases_prepared — #{db_name}: #{marker_table} zaten var, atlanıyor."
          else
            puts "db:ensure_shared_databases_prepared — #{db_name}: #{marker_table} yok, şema yükleniyor..."
            ActiveRecord::Tasks::DatabaseTasks.load_schema(pool.db_config)
          end
        end
      end
    end
  end
end
