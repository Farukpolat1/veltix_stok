class AddConfirmedAtToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :confirmed_at, :datetime

    # E-posta onaylama özelliği bundan sonra oluşturulacak kullanıcılar için
    # geçerli — bu değişiklikten ÖNCE var olan hesaplar (gerçek, hâlihazırda
    # kullanılan hesaplar) aniden kilitlenmesin diye zaten onaylanmış sayılır.
    execute "UPDATE users SET confirmed_at = created_at WHERE confirmed_at IS NULL"
  end

  def down
    remove_column :users, :confirmed_at
  end
end
