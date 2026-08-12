require "test_helper"

class PurchaseInvoicesControllerTest < ActionDispatch::IntegrationTest
  test "pending invoice's supplier, invoice number and date can be corrected" do
    buyer = users(:two)
    buyer.update!(role: :admin)
    sign_in_as buyer
    wrong_supplier = Supplier.create!(name: "Yanlış Tedarikçi")
    right_supplier = Supplier.create!(name: "Doğru Tedarikçi")
    invoice = PurchaseInvoice.create!(invoice_number: "F-001", invoice_date: Date.current, supplier: wrong_supplier, created_by: buyer)

    get edit_purchase_invoice_path(invoice)
    assert_response :success

    patch purchase_invoice_path(invoice), params: { purchase_invoice: { supplier_id: right_supplier.id, invoice_number: "F-DUZELTME", invoice_date: "2026-02-10" } }

    assert_redirected_to edit_purchase_invoice_path(invoice)
    invoice.reload
    assert_equal right_supplier, invoice.supplier
    assert_equal "F-DUZELTME", invoice.invoice_number
    assert_equal Date.parse("2026-02-10"), invoice.invoice_date
  end

  test "an approved invoice's supplier/number/date fields are not shown for editing" do
    buyer = users(:two)
    buyer.update!(role: :admin)
    sign_in_as buyer
    supplier = Supplier.create!(name: "Onaylanmış Fatura Tedarikçisi")
    product = products(:one)
    invoice = PurchaseInvoice.create!(invoice_number: "F-002", invoice_date: Date.current, supplier: supplier, created_by: buyer)
    invoice.purchase_invoice_lines.create!(product: product, external_code: "X", external_name: "X", quantity: 1, unit_price: 10, vat_rate: 20)
    invoice.approve!(user: buyer)

    get edit_purchase_invoice_path(invoice)
    assert_response :success
    assert_select "select[name='purchase_invoice[supplier_id]']", count: 0
  end

  test "deleting an approved invoice reverses the stock movement and restores stock_quantity" do
    buyer = users(:two)
    buyer.update!(role: :admin)
    sign_in_as buyer
    supplier = Supplier.create!(name: "Silinen Fatura Tedarikçisi")
    product = products(:one)
    product.update!(stock_quantity: 5)
    invoice = PurchaseInvoice.create!(invoice_number: "F-003", invoice_date: Date.current, supplier: supplier, created_by: buyer)
    invoice.purchase_invoice_lines.create!(product: product, external_code: "X", external_name: "X", quantity: 4, unit_price: 10, vat_rate: 20)
    invoice.approve!(user: buyer)
    assert_equal 9, product.reload.stock_quantity

    delete purchase_invoice_path(invoice)

    assert_redirected_to purchase_invoices_path
    assert_equal 5, product.reload.stock_quantity
    assert_not PurchaseInvoice.exists?(invoice.id)
  end

  test "depo role cannot delete an approved invoice" do
    buyer = users(:two)
    buyer.update!(role: :depo)
    sign_in_as buyer
    supplier = Supplier.create!(name: "Yetkisiz Silme Tedarikçisi")
    product = products(:one)
    product.update!(stock_quantity: 5)
    invoice = PurchaseInvoice.create!(invoice_number: "F-004", invoice_date: Date.current, supplier: supplier, created_by: buyer)
    invoice.purchase_invoice_lines.create!(product: product, external_code: "X", external_name: "X", quantity: 1, unit_price: 10, vat_rate: 20)
    admin = User.create!(email_address: "gecici_admin2@example.com", password: "sifre1234", role: :admin, company: buyer.company, confirmed_at: Time.current)
    invoice.approve!(user: admin)

    delete purchase_invoice_path(invoice)

    assert_redirected_to root_path
    assert PurchaseInvoice.exists?(invoice.id)
  end
end
