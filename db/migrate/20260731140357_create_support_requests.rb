class CreateSupportRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :support_requests do |t|
      t.references :company, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :category, null: false, default: 0
      t.string :subject
      t.text :message, null: false
      t.integer :status, null: false, default: 0
      t.text :reply
      t.datetime :replied_at

      t.timestamps
    end
  end
end
