class CreateProductTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :product_templates do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name, null: false
      t.string :code
      t.text :description
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :product_templates, [ :company_id, :name ], unique: true

    # company_id burada YOK — SaleLine'ın Sale'e bağlı olup kendi company_id'si
    # taşımaması gibi, TemplateLine da product_template üzerinden (zaten
    # tenant-scope'lu) kapsamını miras alıyor.
    create_table :template_lines do |t|
      t.references :product_template, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.references :default_product, foreign_key: { to_table: :products }

      t.string :label, null: false # "Kasa Profili", "Destek Sacı" — arayüzde gösterilecek isim
      t.integer :variable, null: false, default: 5 # enum: perimeter/sash_perimeter/glass_perimeter/glass_area/total_profile_length/fixed
      t.decimal :coefficient, precision: 10, scale: 4, null: false, default: 1.0
      t.decimal :waste_factor, precision: 6, scale: 4, null: false, default: 1.0 # fire payı — coefficient'ten AYRI
      t.decimal :offset_mm, precision: 10, scale: 2, null: false, default: 0
      t.decimal :fixed_quantity, precision: 10, scale: 2 # variable: fixed olduğunda
      t.integer :position, null: false, default: 0

      t.timestamps
    end
  end
end
