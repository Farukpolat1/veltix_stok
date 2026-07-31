class RemoveSalesCustomersProductionRecipes < ActiveRecord::Migration[8.1]
  def up
    # StockMovement.source polymorphic'tir, DB seviyesinde FK yok — tabloları
    # silmeden önce bu kaynak tiplerine ait hareketleri temizlemezsek
    # Stok Hareketleri sayfası artık var olmayan sınıfı yüklemeye çalışıp çöker.
    execute "DELETE FROM stock_movements WHERE source_type IN ('SaleLine', 'Production', 'ProductionMaterialUsage')"

    # Kaldırılan foto özelliklerinden kalan ActiveStorage ek kayıtlarını temizle.
    execute "DELETE FROM active_storage_attachments WHERE record_type IN ('Product', 'PurchaseInvoice', 'Sale')"

    drop_table :sale_lines
    drop_table :sales
    drop_table :payments
    drop_table :customers
    drop_table :production_material_usages
    drop_table :productions
    drop_table :recipe_items
    drop_table :recipes

    remove_column :products, :barcode, :string
    remove_column :products, :default_sale_price, :decimal
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
