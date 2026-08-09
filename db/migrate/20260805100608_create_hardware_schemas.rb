class CreateHardwareSchemas < ActiveRecord::Migration[8.1]
  def change
    # company_id YOK — bu Egepen'in kendi kataloğuna ait sabit bir referans
    # tablosu (TemplateLine gibi tenant-scope'lu bir kayda değil, doğrudan
    # bir template_line'ın kullandığı ölçü-aralığı eşleştirmesine ait).
    create_table :hardware_schema_cells do |t|
      t.string :system, null: false
      t.string :acilim_tipi, null: false
      t.integer :genislik_min_mm, null: false
      t.integer :genislik_max_mm, null: false
      t.integer :yukseklik_min_mm, null: false
      t.integer :yukseklik_max_mm, null: false

      t.timestamps
    end
    add_index :hardware_schema_cells, [ :system, :acilim_tipi, :genislik_min_mm, :yukseklik_min_mm ],
      name: "idx_hw_cells_lookup"

    create_table :hardware_schema_lines do |t|
      t.references :hardware_schema_cell, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.decimal :quantity, precision: 10, scale: 2, null: false, default: 1

      t.timestamps
    end
  end
end
