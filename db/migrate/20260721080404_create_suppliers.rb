class CreateSuppliers < ActiveRecord::Migration[8.1]
  def change
    create_table :suppliers do |t|
      t.string :name, null: false
      t.string :tax_number
      t.string :phone
      t.text :address

      t.timestamps
    end

    add_index :suppliers, :tax_number, unique: true
  end
end
