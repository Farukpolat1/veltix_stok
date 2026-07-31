# PDF önizleme akışında (Alış/Satış PDF okuma) kullanıcı belgeyi yükleyip
# önizlemeyi görür ama hiç onaylamazsa, yüklenen dosya (ActiveStorage::Blob)
# hiçbir kayda bağlanmadan kalır. Onaylanan belgeler Sale/PurchaseInvoice'a
# eklenip kalıcı olur; sadece hiç onaylanmamış, sahipsiz kalan blob'lar
# burada temizlenir — 24 saatten eski olanlar, hâlâ önizleme ekranında
# olabilecek yeni yüklenen bir belgeyi yanlışlıkla silmemek için.
class PurgeUnattachedBlobsJob < ApplicationJob
  queue_as :default

  def perform
    ActiveStorage::Blob
      .left_joins(:attachments)
      .where(active_storage_attachments: { id: nil })
      .where(created_at: ...24.hours.ago)
      .find_each(&:purge_later)
  end
end
