class CreateCompanies < ActiveRecord::Migration[8.1]
  def change
    create_table :companies do |t|
      t.string :name, null: false
      t.string :slogan
      t.text :address
      t.string :phone
      t.string :website
      t.string :email

      t.timestamps
    end
  end
end
