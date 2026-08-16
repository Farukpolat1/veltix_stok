#!/usr/bin/env bash
# Hata olursa işlemi durdur
set -o errexit

bundle install
bundle exec rake assets:precompile
bundle exec rake assets:clean

# db:migrate yerine db:prepare — ilk deploy'da veritabanı/tablolar hiç yoksa
# (Render'ın yeni oluşturduğu boş Postgres) db:migrate "veritabanı yok" diye
# hata verir; db:prepare hem ilk kurulumda hem sonraki deploy'larda güvenle
# çalışır (primary + solid_cache/queue/cable'ın hepsi için).
bundle exec rake db:prepare

# primary/cache/queue/cable tek bir paylaşılan Postgres'i kullandığında
# (bkz. config/database.yml) db:prepare, cache/queue/cable tablolarını
# sessizce atlıyor — bkz. lib/tasks/ensure_shared_databases.rake.
bundle exec rake db:ensure_shared_databases_prepared