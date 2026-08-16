require "csv"

namespace :customers do
  desc "Eski muhasebe programındaki cari listesini (db/data/customers_cari_import.csv) içeri aktarır"
  task import_cari: :environment do
    company_name = ENV.fetch("COMPANY_NAME", "POLAT PENCERE A.Ş.")
    company = Company.find_or_create_by!(name: company_name)

    path = Rails.root.join("db/data/customers_cari_import.csv")
    created = 0
    updated = 0

    ActsAsTenant.with_tenant(company) do
      CSV.foreach(path, headers: true) do |row|
        customer = Customer.find_or_initialize_by(code: row["code"])
        customer.name = row["name"]
        # CSV'deki balance = Alacak - Borç; opening_balance (pozitif = bize
        # borçlu) için işaret ters çevrilir — bkz. bu CSV'yi üreten import.
        customer.opening_balance = -row["balance"].to_f
        was_new_record = customer.new_record?
        customer.save!
        was_new_record ? created += 1 : updated += 1
      end
    end

    puts "Tamamlandı: #{created} yeni müşteri, #{updated} güncellenen müşteri."
  end
end
