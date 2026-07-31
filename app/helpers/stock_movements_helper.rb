module StockMovementsHelper
  # Stok hareketinin kaynağı olan satış/faturaya, o kaydı görüntüleme yetkisi
  # varsa link olarak, yoksa düz metin olarak gösterir.
  def stock_movement_source_link(movement)
    case movement.source
    when PurchaseInvoiceLine
      invoice = movement.source.purchase_invoice
      return movement.source_label unless policy(invoice).edit?
      target = invoice.needs_line_matching? ? edit_purchase_invoice_path(invoice) : items_purchase_invoice_path(invoice)
      link_to movement.source_label, target
    when SaleLine
      sale = movement.source.sale
      return movement.source_label unless policy(sale).items?
      link_to movement.source_label, items_sale_path(sale)
    else
      movement.source_label
    end
  end
end
