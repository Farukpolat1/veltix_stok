# Veltix

PVC pencere/kapı ve imalat sektörüne özel, çok kiracılı (multi-tenant) depo,
stok, satış/alış ve cari hesap yönetim platformu. Rails 8.1 üzerine kurulu;
yapay zeka (Gemini) ile fatura/sipariş PDF'lerinden otomatik veri okuma
içerir.

## Teknoloji

- **Ruby** 3.3.7 / **Rails** 8.1
- **PostgreSQL** — birincil veritabanı
- **Solid Queue / Solid Cache / Solid Cable** — arka plan işleri, cache ve
  Action Cable için ayrı veritabanı gerektirmeyen Rails 8 varsayılanları
- **Pundit** — rol bazlı yetkilendirme (admin / depo / satış)
- **acts_as_tenant** — satır bazlı çok kiracılık; her `Company` kendi
  verisini görür, aralarında hiçbir sorgu sızıntısı olmaz
- **Turbo + Stimulus** — sayfa yenilemeden (SPA hissi veren) etkileşimler
- **Bootstrap 5** (cssbundling-rails + sass) — arayüz
- **Prawn** — PDF çıktıları (irsaliye, cari ekstre, aylık rapor)
- **Kamal** — Docker container olarak deploy

## Gereksinimler

- Ruby 3.3.7 (bkz. `.ruby-version`)
- Node 20.11.1 (bkz. `.node-version`) + Yarn — CSS build için
- PostgreSQL (yerelde çalışıyor olmalı)

## Kurulum

```bash
bin/setup
```

Bu script bağımlılıkları (`bundle install`, `yarn install`), veritabanını
(`db:prepare`) hazırlar ve `bin/dev`'i başlatır. Elle yapmak isterseniz:

```bash
bundle install
yarn install
bin/rails db:prepare
bin/rails db:seed   # ilk firma + varsayılan kategori/seçenekleri oluşturur
bin/dev
```

`bin/dev`, hem Rails sunucusunu hem de CSS'i izleyip yeniden derleyen
`watch:css` sürecini birlikte başlatır (bkz. `Procfile.dev`).

## Ortam Değişkenleri

Yerelde `.env` dosyası oluşturup `.env.example`'ı örnek alın:

```bash
cp .env.example .env
```

| Değişken | Ne için | Zorunlu mu? |
|---|---|---|
| `GEMINI_API_KEY` | Fatura/sipariş/katalog PDF'lerinden otomatik veri okuma | PDF okuma özellikleri için evet |
| `RESEND_API_KEY` | Şifre sıfırlama, hesap onay, demo/destek talebi e-postaları | Production'da evet |
| `MAILER_FROM_ADDRESS` | E-postaların "kimden" adresi (Resend'de doğrulanmış olmalı) | Production'da evet |
| `APP_HOST` | E-posta linklerinin işaret edeceği alan adı | Production'da evet |
| `SENTRY_DSN` | Production'da yakalanmayan hataların (500) otomatik bildirimi | Opsiyonel |
| `R2_ACCESS_KEY_ID` / `R2_SECRET_ACCESS_KEY` / `R2_REGION` / `R2_BUCKET` / `R2_ENDPOINT` | Yüklenen PDF/görsellerin Cloudflare R2'de saklanması | Production'da evet (yoksa container diski kullanılır, kalıcı değildir) |

Boş bırakılan değişkenler yerelde/test'te sessizce devre dışı kalır
(örn. Sentry hiç etkinleşmez, e-postalar `ActionMailer::Base.deliveries`
içine düşer, dosyalar `storage/` altında yerel diskte tutulur).

## Test ve Kod Kalitesi

```bash
bin/rails test              # tüm test paketi
bundle exec rubocop app/ config/ test/   # stil/kalite kontrolü
bundle exec brakeman        # güvenlik taraması
```

## Mimari Notları

- **Çok kiracılık:** Her iş verisi modeli (`Product`, `Sale`,
  `PurchaseInvoice`, `Customer`, `Supplier`, ...) `acts_as_tenant(:company)`
  taşır; sorgular otomatik olarak o an giriş yapmış kullanıcının firmasına
  göre filtrelenir (bkz. `ApplicationController#set_tenant_from_current_user`).
  `User` bu kurala dahil değildir (giriş anında hangi firmaya ait olduğu
  henüz bilinmez).
- **Yetkilendirme:** Pundit — her controller `authorize`/`policy_scope`
  çağırır, roller `app/policies/` altında tanımlıdır.
- **Yapay zeka ile PDF okuma:** `app/services/invoices/`,
  `app/services/products/`, `app/services/catalogs/` altındaki servisler
  Gemini API'yi kullanarak fatura/sipariş/katalog PDF'lerinden veri çıkarır;
  sonuç kaydedilmeden önce her zaman bir önizleme ekranında kullanıcıya
  gösterilir.
- **Yeni firma eklemek:** Şu an self-servis kayıt yok (bilinçli olarak
  ertelendi). Konsoldan:
  ```ruby
  company = Company.create!(name: "...")
  ActsAsTenant.with_tenant(company) { Companies::SeedDefaults.call }
  ```

## Deployment

[Kamal](https://kamal-deploy.org) ile Docker container olarak deploy edilir
(bkz. `config/deploy.yml`). Solid Queue worker'ı ayrı bir sunucu/rol
gerektirmez — `SOLID_QUEUE_IN_PUMA: true` ile web sürecinin içinde çalışır.

```bash
bin/kamal setup   # ilk kurulum
bin/kamal deploy  # sonraki deploy'lar
```

Sırlar (`RAILS_MASTER_KEY`, `RESEND_API_KEY`, `GEMINI_API_KEY`,
`SENTRY_DSN`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`) `.kamal/secrets`
üzerinden enjekte edilir — gerçek değerleri asla repoya commit etmeyin.
