require "csv"

namespace :customers do
  desc "Eski muhasebe programındaki cari listesini (db/data/customers_cari_import.csv) içeri aktarır"
  task import_cari: :environment do
    path = Rails.root.join("db/data/customers_cari_import.csv")
    created = 0
    updated = 0

    CSV.foreach(path, headers: true) do |row|
      customer = Customer.find_or_initialize_by(code: row["code"])
      customer.name = row["name"]
      customer.opening_balance = row["balance"]
      was_new_record = customer.new_record?
      customer.save!
      was_new_record ? created += 1 : updated += 1
    end

    puts "Tamamlandı: #{created} yeni müşteri, #{updated} güncellenen müşteri."
  end
end
