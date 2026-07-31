class CreateCategoryOptions < ActiveRecord::Migration[8.1]
  BRANDS = [ "Egepen", "Vorne", "Accado", "Diğer" ].freeze

  PROFILE_COLORS = [
    "Beyaz", "Krem", "Gümüş", "Vizon", "Antrasit Gri", "Metalik Antrasit Gri", "Kül Siyah", "Titanium Sand",
    "Altın Meşe", "Antik Meşe", "Koyu Meşe", "Fındık", "Ceviz", "Winchester", "Budaklı Winchester", "Venge",
    "Kiraz", "Şam Kırması"
  ].freeze

  ACCESSORY_TYPES = [
    "İspanyolet / Kilit Mekanizması",
    "Kilitleme Bileşenleri (Karşılık/Kilit Göbeği)",
    "Kollar",
    "Menteşe Sistemleri (Pencere)",
    "Kapı Menteşeleri",
    "Kanat Aksesuarları (Makas/Köşe Aparatı)",
    "Vida ve Bağlantı Elemanları",
    "Sineklik Aksesuarları",
    "Diğer Aksesuar"
  ].freeze

  def up
    create_table :category_options do |t|
      t.integer :option_type, null: false
      t.string :name, null: false

      t.timestamps
    end
    add_index :category_options, [ :option_type, :name ], unique: true

    now = Time.current
    rows = BRANDS.map { |name| { option_type: 0, name: name, created_at: now, updated_at: now } } +
      PROFILE_COLORS.map { |name| { option_type: 1, name: name, created_at: now, updated_at: now } } +
      ACCESSORY_TYPES.map { |name| { option_type: 2, name: name, created_at: now, updated_at: now } }
    execute(
      "INSERT INTO category_options (option_type, name, created_at, updated_at) VALUES " +
      rows.map { |r| "(#{r[:option_type]}, #{quote(r[:name])}, #{quote(r[:created_at])}, #{quote(r[:updated_at])})" }.join(", ")
    )
  end

  def down
    drop_table :category_options
  end
end
