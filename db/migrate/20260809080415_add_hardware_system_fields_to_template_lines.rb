class AddHardwareSystemFieldsToTemplateLines < ActiveRecord::Migration[8.1]
  def change
    add_column :template_lines, :hardware_system, :string
    add_column :template_lines, :hardware_acilim_tipi, :string
    change_column_null :template_lines, :hardware_schema_lookup, false, false
    change_column_default :template_lines, :hardware_schema_lookup, from: nil, to: false
  end
end
