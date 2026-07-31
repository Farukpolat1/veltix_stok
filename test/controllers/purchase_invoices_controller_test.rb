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
end
