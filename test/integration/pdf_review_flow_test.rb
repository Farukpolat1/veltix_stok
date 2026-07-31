require "test_helper"

class PdfReviewFlowTest < ActionDispatch::IntegrationTest
  def stub_gemini_extraction(data)
    stub_class_method(Gemini::DocumentExtractor, :call, data) { yield }
  end

  def stub_class_method(klass, method_name, return_value)
    original = klass.method(method_name)
    klass.define_singleton_method(method_name) { |*| return_value }
    yield
  ensure
    klass.define_singleton_method(method_name, original)
  end

  test "sale pdf import: extract shows review form, confirm persists nothing until submitted, edited data is saved" do
    seller = users(:one)
    seller.update!(role: :admin)
    sign_in_as seller

    extracted = {
      customer: { code: nil, name: "Yeni Test Müşteri", tax_number: nil },
      sale_date: "2026-07-20",
      order_number: "SP-999",
      discount_rate: 10,
      lines: [
        { name: "Test Profil 6m", quantity: 3, unit: "adet", unit_price: 100, vat_rate: 20 }
      ]
    }

    assert_no_difference [ "Sale.count", "Customer.count" ] do
      stub_gemini_extraction(extracted) do
        post new_pdf_sales_path, params: { sale: { pdf_file: fixture_file_upload("dummy.pdf", "application/pdf") } }
      end
    end

    assert_response :success
    assert_select "form[action=?]", confirm_pdf_sales_path

    assert_difference [ "Sale.count", "Customer.count", "SaleLine.count" ], 1 do
      post confirm_pdf_sales_path, params: {
        sale: {
          sale_date: "2026-07-21",
          order_number: "SP-999-EDITED",
          discount_rate: "5",
          customer: { code: "", name: "Düzenlenmiş Müşteri Adı", tax_number: "" },
          lines: [ { name: "Test Profil 6m", quantity: "3", unit: "adet", unit_price: "100", vat_rate: "20" } ]
        }
      }
    end

    sale = Sale.order(:created_at).last
    assert_redirected_to items_sale_path(sale)
    assert_equal "Düzenlenmiş Müşteri Adı", sale.customer.name
    assert_equal "SP-999-EDITED", sale.external_order_number
  end

  test "purchase invoice pdf import: extract shows review form, confirm persists edited data" do
    buyer = users(:two)
    buyer.update!(role: :admin)
    sign_in_as buyer

    extracted = {
      invoice_number: "F-2026-01",
      invoice_date: "2026-07-15",
      supplier: { name: "Yeni Test Tedarikçi", tax_number: nil },
      lines: [
        { code: "SKU-1", name: "Test Aksesuar", quantity: 5, unit_price: 20, vat_rate: 20 }
      ]
    }

    assert_no_difference [ "PurchaseInvoice.count", "Supplier.count" ] do
      stub_gemini_extraction(extracted) do
        post new_pdf_purchase_invoices_path, params: { purchase_invoice: { pdf_file: fixture_file_upload("dummy.pdf", "application/pdf") } }
      end
    end

    assert_response :success
    assert_select "form[action=?]", confirm_pdf_purchase_invoices_path

    assert_difference [ "PurchaseInvoice.count", "Supplier.count", "PurchaseInvoiceLine.count" ], 1 do
      post confirm_pdf_purchase_invoices_path, params: {
        purchase_invoice: {
          invoice_number: "F-2026-01-EDITED",
          invoice_date: "2026-07-16",
          supplier: { name: "Düzenlenmiş Tedarikçi Adı", tax_number: "" },
          lines: [ { code: "SKU-1", name: "Test Aksesuar", quantity: "5", unit_price: "20", vat_rate: "20" } ]
        }
      }
    end

    invoice = PurchaseInvoice.order(:created_at).last
    assert_redirected_to edit_purchase_invoice_path(invoice)
    assert_equal "Düzenlenmiş Tedarikçi Adı", invoice.supplier.name
    assert_equal "F-2026-01-EDITED", invoice.invoice_number
  end

  test "confirmed sale keeps the uploaded pdf attached for later viewing" do
    seller = users(:one)
    seller.update!(role: :admin)
    sign_in_as seller

    extracted = {
      customer: { name: "Belge Saklama Testi" }, sale_date: "2026-07-20", lines: [ { name: "Ürün", quantity: 1, unit: "adet", unit_price: 10, vat_rate: 20 } ]
    }

    stub_gemini_extraction(extracted) do
      post new_pdf_sales_path, params: { sale: { pdf_file: fixture_file_upload("dummy.pdf", "application/pdf") } }
    end
    assert_response :success
    signed_id = css_select("input[name='sale[pdf_blob_signed_id]']").first["value"]
    assert signed_id.present?, "review form should carry the uploaded pdf's blob signed id"

    post confirm_pdf_sales_path, params: {
      sale: { sale_date: "2026-07-20", pdf_blob_signed_id: signed_id, customer: { name: "Belge Saklama Testi" }, lines: [ { name: "Ürün", quantity: "1", unit: "adet", unit_price: "10", vat_rate: "20" } ] }
    }

    sale = Sale.order(:created_at).last
    assert sale.source_pdfs.attached?, "the source pdf should remain attached to the sale for later viewing"
  end

  test "sale pdf confirm failure returns the user to the review screen with their edits and pdf preview intact" do
    seller = users(:one)
    seller.update!(role: :admin)
    sign_in_as seller

    extracted = {
      customer: { name: "Hata Testi Müşteri" }, sale_date: "2026-07-20", order_number: "SP-777",
      lines: [ { name: "Ürün A", quantity: 1, unit: "adet", unit_price: 10, vat_rate: 20 } ]
    }

    stub_gemini_extraction(extracted) do
      post new_pdf_sales_path, params: { sale: { pdf_file: fixture_file_upload("dummy.pdf", "application/pdf") } }
    end
    assert_response :success
    signed_id = css_select("input[name='sale[pdf_blob_signed_id]']").first["value"]

    assert_no_difference [ "Sale.count", "Customer.count" ] do
      post confirm_pdf_sales_path, params: {
        sale: {
          sale_date: "2026-07-20", order_number: "SP-777-DUZENLENDI", pdf_blob_signed_id: signed_id,
          customer: { name: "Hata Testi Müşteri" },
          # kullanıcı ürün adını yanlışlıkla sildi — persist bunu reddetmeli
          lines: [ { name: "", quantity: "1", unit: "adet", unit_price: "10", vat_rate: "20" } ]
        }
      }
    end

    assert_response :unprocessable_entity
    # kullanıcı review ekranına geri dönmeli, önceki düzenlemesi (sipariş no) korunmalı, pdf önizlemesi hâlâ orada
    assert_select "form[action=?]", confirm_pdf_sales_path
    assert_select "input[name='sale[order_number]'][value=?]", "SP-777-DUZENLENDI"
    assert_select "iframe"
  end

  test "confirming the same purchase invoice pdf twice shows a friendly validation error instead of crashing" do
    buyer = users(:two)
    buyer.update!(role: :admin)
    sign_in_as buyer

    extracted = {
      invoice_number: "TEKRAR-001", invoice_date: "2026-07-20",
      supplier: { name: "Tekrar Testi Tedarikçi" },
      lines: [ { name: "Ürün", quantity: 1, unit_price: 10, vat_rate: 20 } ]
    }

    confirm = lambda do
      post confirm_pdf_purchase_invoices_path, params: {
        purchase_invoice: {
          invoice_number: "TEKRAR-001", invoice_date: "2026-07-20",
          supplier: { name: "Tekrar Testi Tedarikçi" },
          lines: [ { name: "Ürün", quantity: "1", unit_price: "10", vat_rate: "20" } ]
        }
      }
    end

    assert_difference "PurchaseInvoice.count", 1 do
      confirm.call
    end
    assert_response :redirect

    assert_no_difference "PurchaseInvoice.count" do
      assert_nothing_raised { confirm.call }
    end
    assert_response :unprocessable_entity
    assert_includes @response.body, "zaten kayıtlı"
  end

  test "product extract_pdf prefills the new-product form without saving" do
    admin = users(:one)
    admin.update!(role: :admin)
    sign_in_as admin

    extracted = { name: "Teknik Föyden Okunan Ürün", code: "TF-001", unit: "adet", category_name: nil }

    assert_no_difference "Product.count" do
      stub_class_method(Products::PdfReader, :call, extracted) do
        post extract_pdf_products_path, params: { pdf_file: fixture_file_upload("dummy.pdf", "application/pdf") }
      end
    end

    assert_response :success
    assert_select "input[name='product[name]'][value=?]", "Teknik Föyden Okunan Ürün"
    assert_select "input[name='product[code]'][value=?]", "TF-001"
  end

  test "sale pdf import shows matched-customer banner when tax number matches an existing customer" do
    seller = users(:one)
    seller.update!(role: :admin)
    sign_in_as seller
    existing = Customer.create!(name: "Zaten Var Olan Müşteri", tax_number: "1112223334")

    extracted = {
      customer: { code: nil, name: "Belgede Farklı Yazan Ad", tax_number: "1112223334" },
      sale_date: "2026-07-20", order_number: nil, discount_rate: 0,
      lines: [ { name: "Test Ürün", quantity: 1, unit: "adet", unit_price: 10, vat_rate: 20 } ]
    }

    stub_gemini_extraction(extracted) do
      post new_pdf_sales_path, params: { sale: { pdf_file: fixture_file_upload("dummy.pdf", "application/pdf") } }
    end

    assert_response :success
    assert_includes @response.body, "eşleşti"
    assert_includes @response.body, existing.name
  end

  test "sale pdf import creates new customer with tax office and address when no match found" do
    seller = users(:one)
    seller.update!(role: :admin)
    sign_in_as seller

    extracted = {
      customer: { code: nil, name: "Hiç Olmayan Müşteri", tax_number: nil },
      sale_date: "2026-07-20", order_number: nil, discount_rate: 0,
      lines: [ { name: "Test Ürün", quantity: 1, unit: "adet", unit_price: 10, vat_rate: 20 } ]
    }

    stub_gemini_extraction(extracted) do
      post new_pdf_sales_path, params: { sale: { pdf_file: fixture_file_upload("dummy.pdf", "application/pdf") } }
    end
    assert_response :success
    assert_includes @response.body, "yeni müşteri"

    post confirm_pdf_sales_path, params: {
      sale: {
        sale_date: "2026-07-20",
        customer: { name: "Hiç Olmayan Müşteri", tax_office: "Esenyurt V.D.", address: "Test Mah. No:1", phone: "5551234567" },
        lines: [ { name: "Test Ürün", quantity: "1", unit: "adet", unit_price: "10", vat_rate: "20" } ]
      }
    }

    customer = Customer.find_by!(name: "Hiç Olmayan Müşteri")
    assert_equal "Esenyurt V.D.", customer.tax_office
    assert_equal "Test Mah. No:1", customer.address
  end

  test "customer extract_pdf prefills the new-customer form without saving" do
    admin = users(:one)
    admin.update!(role: :admin)
    sign_in_as admin

    extracted = { name: "Vergi Levhasından Okunan Firma", tax_number: "9998887776", tax_office: "Kadıköy V.D.", address: "Örnek Sk. No:5", phone: "5559876543" }

    assert_no_difference "Customer.count" do
      stub_class_method(Invoices::CompanyDocumentExtractor, :call, extracted) do
        post extract_pdf_customers_path, params: { pdf_file: fixture_file_upload("dummy.pdf", "application/pdf") }
      end
    end

    assert_response :success
    assert_select "input[name='customer[name]'][value=?]", "Vergi Levhasından Okunan Firma"
    assert_select "input[name='customer[tax_office]'][value=?]", "Kadıköy V.D."
  end

  test "supplier extract_pdf prefills the new-supplier form without saving" do
    admin = users(:two)
    admin.update!(role: :admin)
    sign_in_as admin

    extracted = { name: "Vergi Levhasından Okunan Tedarikçi", tax_number: "9998887777", tax_office: "Ümraniye V.D.", address: "Örnek Cd. No:9", phone: "5551112233" }

    assert_no_difference "Supplier.count" do
      stub_class_method(Invoices::CompanyDocumentExtractor, :call, extracted) do
        post extract_pdf_suppliers_path, params: { pdf_file: fixture_file_upload("dummy.pdf", "application/pdf") }
      end
    end

    assert_response :success
    assert_select "input[name='supplier[name]'][value=?]", "Vergi Levhasından Okunan Tedarikçi"
    assert_select "input[name='supplier[tax_office]'][value=?]", "Ümraniye V.D."
  end

  test "import lines from pdf into an existing pending sale" do
    seller = users(:one)
    seller.update!(role: :admin)
    sign_in_as seller
    customer = Customer.create!(name: "Var Olan Müşteri")
    sale = Sale.create!(sale_date: Date.current, customer: customer, created_by: seller)

    extracted_lines = { lines: [ { name: "Eklenecek Ürün", quantity: 2, unit: "adet", unit_price: 50, vat_rate: 20 } ], discount_rate: 0 }

    stub_gemini_extraction(extracted_lines) do
      post import_lines_pdf_sale_path(sale), params: { sale: { pdf_file: fixture_file_upload("dummy.pdf", "application/pdf") } }
    end
    assert_response :success
    assert_select "form[action=?]", confirm_import_lines_sale_path(sale)

    assert_difference "sale.sale_lines.reload.count", 1 do
      post confirm_import_lines_sale_path(sale), params: {
        sale: { discount_rate: "0", lines: [ { name: "Eklenecek Ürün", quantity: "2", unit: "adet", unit_price: "50", vat_rate: "20" } ] }
      }
    end
    assert_redirected_to items_sale_path(sale)
  end

  test "import lines from pdf into an existing pending purchase invoice" do
    buyer = users(:two)
    buyer.update!(role: :admin)
    sign_in_as buyer
    supplier = Supplier.create!(name: "Var Olan Tedarikçi")
    invoice = PurchaseInvoice.create!(invoice_number: "IMP-1", invoice_date: Date.current, supplier: supplier, created_by: buyer)

    extracted_lines = { lines: [ { code: "X1", name: "Eklenecek Malzeme", quantity: 4, unit_price: 30, vat_rate: 20 } ] }

    stub_gemini_extraction(extracted_lines) do
      post import_lines_pdf_purchase_invoice_path(invoice), params: { purchase_invoice: { pdf_file: fixture_file_upload("dummy.pdf", "application/pdf") } }
    end
    assert_response :success
    assert_select "form[action=?]", confirm_import_lines_purchase_invoice_path(invoice)

    assert_difference "invoice.purchase_invoice_lines.reload.count", 1 do
      post confirm_import_lines_purchase_invoice_path(invoice), params: {
        purchase_invoice: { lines: [ { code: "X1", name: "Eklenecek Malzeme", quantity: "4", unit_price: "30", vat_rate: "20" } ] }
      }
    end
    assert_redirected_to items_purchase_invoice_path(invoice)
  end
end
