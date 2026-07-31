# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

polat_pencere = Company.find_or_create_by!(name: "POLAT PENCERE A.Ş.") do |c|
  c.slogan = "Pencerede Çeyrek Asır"
  c.address = "Mecidiye Mah. Fatih Bulvarı No:478, Sultanbeyli, İstanbul"
  c.phone = "0216 498 9 999"
  c.website = "www.polatpencere.com"
  c.email = "mim.murat@polatpencere.com"
end

# Yeni bir firma eklerken de aynı servis ActsAsTenant.with_tenant(yeni_firma)
# bloğu içinde çağrılır (bkz. app/services/companies/seed_defaults.rb).
ActsAsTenant.with_tenant(polat_pencere) { Companies::SeedDefaults.call }
