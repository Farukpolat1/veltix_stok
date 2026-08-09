class AddHardwareSchemaLookupToTemplateLines < ActiveRecord::Migration[8.1]
  def change
    add_column :template_lines, :hardware_schema_lookup, :boolean, null: false, default: false
    add_column :template_lines, :hardware_system, :string
    add_column :template_lines, :hardware_acilim_tipi, :string
  end
end
