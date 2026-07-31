module Companies
  # Bir firma için varsayılan kategori + özellik grubu (Marka/Renk/Aksesuar Alt
  # Türü/Seri) seed'ini oluşturur — hem db/seeds.rb hem de yeni bir firma
  # eklerken (bkz. plan: "Yeni firma nasıl eklenir") kullanılır. Çağıran,
  # ActsAsTenant.with_tenant(firma) bloğu içinde çağırmalı.
  class SeedDefaults
    def self.call = new.call

    def call
      seed_categories
      seed_option_groups
    end

    private
      def seed_categories
        [
          { name: "Kasa Profili", code: "PRF-KASA-BYZ", product_type: :profil, color: "Beyaz", brand: "Egepen" },
          { name: "Kanat Profili", code: "PRF-KANAT-BYZ", product_type: :profil, color: "Beyaz", brand: "Egepen" },
          { name: "Ortakayıt Profili", code: "PRF-ORTAKAYIT-BYZ", product_type: :profil, color: "Beyaz", brand: "Egepen" },
          { name: "Cam Çıtası (Tekcam)", code: "PRF-CAMCITA-TEK-BYZ", product_type: :profil, color: "Beyaz", brand: "Egepen" },
          { name: "Cam Çıtası (Çiftcam)", code: "PRF-CAMCITA-CIFT-BYZ", product_type: :profil, color: "Beyaz", brand: "Egepen" },
          { name: "İspanyolet / Kilit Mekanizması", code: "AKS-ISPANYOLET", product_type: :aksesuar, accessory_type: "İspanyolet / Kilit Mekanizması", brand: "Accado" },
          { name: "Kilitleme Bileşenleri (Kilit Göbeği/Karşılık)", code: "AKS-KILIT-GOBEGI", product_type: :aksesuar, accessory_type: "Kilitleme Bileşenleri (Karşılık/Kilit Göbeği)", brand: "Accado" },
          { name: "Kollar", code: "AKS-KOL", product_type: :aksesuar, accessory_type: "Kollar", brand: "Vorne" },
          { name: "Menteşe Sistemleri (Pencere)", code: "AKS-MENTESE-PENCERE", product_type: :aksesuar, accessory_type: "Menteşe Sistemleri (Pencere)", brand: "Vorne" },
          { name: "Kapı Menteşeleri", code: "AKS-MENTESE-KAPI", product_type: :aksesuar, accessory_type: "Kapı Menteşeleri", brand: "Vorne" },
          { name: "Kanat Aksesuarları (Makas/Köşe Aparatı)", code: "AKS-KANAT-AKS", product_type: :aksesuar, accessory_type: "Kanat Aksesuarları (Makas/Köşe Aparatı)", brand: "Vorne" },
          { name: "Vida ve Bağlantı Elemanları", code: "AKS-VIDA", product_type: :aksesuar, accessory_type: "Vida ve Bağlantı Elemanları", brand: "Diğer" },
          { name: "Sineklik Aksesuarları", code: "AKS-SINEKLIK", product_type: :aksesuar, accessory_type: "Sineklik Aksesuarları", brand: "Diğer" },
          { name: "Takviye Sacı", code: "DGR-SAC-TAKVIYE", product_type: :diger },
          { name: "Destek Sacı", code: "DGR-SAC-DESTEK", product_type: :diger },
          { name: "Cam", code: "DGR-CAM", product_type: :diger },
          { name: "Conta", code: "DGR-CONTA", product_type: :diger },
          { name: "Silikon", code: "DGR-SILIKON", product_type: :diger },
          { name: "Panjur", code: "DGR-PANJUR", product_type: :diger },
          { name: "Yardımcı Malzemeler", code: "DGR-YARDIMCI", product_type: :diger },
          { name: "Sınıflandırılmamış", code: "DGR-SINIFLANDIRILMAMIS", product_type: :diger }
        ].each do |attrs|
          category = Category.find_or_initialize_by(name: attrs[:name])
          category.update!(attrs)
        end
      end

      def seed_option_groups
        {
          "Marka" => [ "Egepen", "Vorne", "Accado", "Diğer" ],
          "Renk" => [
            "Beyaz", "Krem", "Gümüş", "Vizon", "Antrasit Gri", "Metalik Antrasit Gri", "Kül Siyah", "Titanium Sand",
            "Altın Meşe", "Antik Meşe", "Koyu Meşe", "Fındık", "Ceviz", "Winchester", "Budaklı Winchester", "Venge",
            "Kiraz", "Şam Kırması"
          ],
          "Aksesuar Alt Türü" => [
            "İspanyolet / Kilit Mekanizması",
            "Kilitleme Bileşenleri (Karşılık/Kilit Göbeği)",
            "Kollar",
            "Menteşe Sistemleri (Pencere)",
            "Kapı Menteşeleri",
            "Kanat Aksesuarları (Makas/Köşe Aparatı)",
            "Vida ve Bağlantı Elemanları",
            "Sineklik Aksesuarları",
            "Diğer Aksesuar"
          ],
          "Seri" => [ "70 Serisi", "80 Serisi", "Sürme Seri", "Isıcamlı Sürme" ]
        }.each do |group_name, names|
          group = CategoryOptionGroup.find_or_create_by!(name: group_name)
          names.each { |name| CategoryOption.find_or_create_by!(category_option_group: group, name: name) }
        end
      end
  end
end
