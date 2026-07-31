class AddCompanyToUsers < ActiveRecord::Migration[8.1]
  def up
    add_reference :users, :company, foreign_key: true

    company_id = execute("SELECT id FROM companies ORDER BY id LIMIT 1").first&.fetch("id")
    company_id ||= execute(
      "INSERT INTO companies (name, slogan, address, phone, website, email, created_at, updated_at) VALUES " \
      "(#{quote('POLAT PENCERE A.Ş.')}, #{quote('Pencerede Çeyrek Asır')}, " \
      "#{quote('Mecidiye Mah. Fatih Bulvarı No:478, Sultanbeyli, İstanbul')}, #{quote('0216 498 9 999')}, " \
      "#{quote('www.polatpencere.com')}, #{quote('mim.murat@polatpencere.com')}, #{quote(Time.current)}, #{quote(Time.current)}) RETURNING id"
    ).first["id"]

    execute("UPDATE users SET company_id = #{company_id} WHERE company_id IS NULL")
    change_column_null :users, :company_id, false
  end

  def down
    remove_reference :users, :company, foreign_key: true
  end
end
