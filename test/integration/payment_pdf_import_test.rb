require "test_helper"

class PaymentPdfImportTest < ActionDispatch::IntegrationTest
  def stub_gemini_extraction(data)
    original = Gemini::DocumentExtractor.method(:call)
    Gemini::DocumentExtractor.define_singleton_method(:call) { |*| data }
    yield
  ensure
    Gemini::DocumentExtractor.define_singleton_method(:call, original)
  end

  test "customer payment pdf parse fills review form with real extracted data" do
    admin = users(:one)
    admin.update!(role: :admin)
    sign_in_as admin
    customer = Customer.create!(name: "Test Müşteri")

    file = fixture_file_upload(Rails.root.join("test/fixtures/files/dummy.pdf"), "application/pdf")

    stub_gemini_extraction(amount: 987.65, paid_at: "2026-05-01", payment_method: "Banka Havalesi", note: "test dekont") do
      post parse_pdf_customer_customer_payments_path(customer), params: { file: file }
    end

    assert_redirected_to new_customer_customer_payment_path(customer)
    follow_redirect!
    assert_response :success
    assert_match "987.65", response.body
  end

  test "supplier payment pdf parse fills review form with real extracted data" do
    admin = users(:one)
    admin.update!(role: :admin)
    sign_in_as admin
    supplier = Supplier.create!(name: "Test Tedarikçi")

    file = fixture_file_upload(Rails.root.join("test/fixtures/files/dummy.pdf"), "application/pdf")

    stub_gemini_extraction(amount: 555.0, paid_at: "2026-05-02", note: "tedarikci test") do
      post parse_pdf_supplier_supplier_payments_path(supplier), params: { file: file }
    end

    assert_redirected_to new_supplier_supplier_payment_path(supplier)
    follow_redirect!
    assert_response :success
    assert_match "555.0", response.body
  end
end
