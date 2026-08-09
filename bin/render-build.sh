#!/usr/bin/env bash
# Hata olursa işlemi durdur
set -o errexit

bundle install
bundle exec rake assets:precompile
bundle exec rake assets:clean
bundle exec rake db:migrate