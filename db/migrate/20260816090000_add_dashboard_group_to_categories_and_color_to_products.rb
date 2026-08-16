class AddDashboardGroupToCategoriesAndColorToProducts < ActiveRecord::Migration[8.1]
  def change
    # İş Özeti'ndeki beyaz/renkli kartlarının hangi "kova"ya (mtül, pervaz,
    # lambri, cam, kapı aksesuarı, çift/tek açılım aksesuarı) toplanacağını
    # kategori bazında admin ekrandan atanabilir tutar — 46 kategori bir kere
    # sınıflandırılır, kod içine gömülmez (bkz. şirketin "configurable over
    # hardcoded" tercihi).
    add_column :categories, :dashboard_group, :integer

    # Aksesuar/cam ürünlerinde renk katalogda yoktu (profil ürünlerinin
    # aksine, kategoride değil ürün adında/kodunda geçiyordu) — ürün bazında
    # elle etiketlenebilir bir renk alanı.
    add_column :products, :color, :string
    add_index :products, :color
  end
end
