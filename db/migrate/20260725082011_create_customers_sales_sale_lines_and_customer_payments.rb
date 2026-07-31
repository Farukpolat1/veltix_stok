class CreateCustomersSalesSaleLinesAndCustomerPayments < ActiveRecord::Migration[8.1]
  def change
    create_table :customers do |t|
      t.string :name, null: false
      t.string :tax_number
      t.string :phone
      t.text :address

      t.timestamps
    end
    add_index :customers, :tax_number, unique: true

    create_table :sales do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :sale_number, null: false
      t.date :sale_date, null: false
      t.integer :status, null: false, default: 0

      t.timestamps
    end
    add_index :sales, :sale_number, unique: true

    create_table :sale_lines do |t|
      t.references :sale, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.decimal :quantity, null: false
      t.decimal :unit_price, null: false
      t.decimal :vat_rate, null: false, default: 20

      t.timestamps
    end

    create_table :customer_payments do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.decimal :amount, null: false
      t.datetime :paid_at, null: false
      t.text :note

      t.timestamps
    end
  end
end
