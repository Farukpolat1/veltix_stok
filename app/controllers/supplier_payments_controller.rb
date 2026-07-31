class SupplierPaymentsController < ApplicationController
  before_action :set_supplier
  after_action :verify_authorized

  # 1. ADIM: PDF'in yüklenip Gemini ile okunduğu ara action
  def parse_pdf
    authorize SupplierPayment
    uploaded_file = params[:file]

    if uploaded_file.blank?
      return redirect_to new_supplier_supplier_payment_path(@supplier), alert: "Lütfen bir PDF dosyası seçin."
    end

    bytes = uploaded_file.read
    extracted_data = SupplierPayments::PdfReader.call(bytes)
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(bytes), filename: uploaded_file.original_filename.presence || "dekont.pdf", content_type: "application/pdf")

    session[:temp_supplier_payment_data] = extracted_data
    session[:supplier_pdf_signed_id] = blob.signed_id

    redirect_to new_supplier_supplier_payment_path(@supplier), notice: "PDF başarıyla okundu. Lütfen bilgileri kontrol edip onaylayın."
  rescue SupplierPayments::PdfReader::ParseError => e
    redirect_to new_supplier_supplier_payment_path(@supplier), alert: e.message
  end

  # 2. ADIM: Onay ekranı
  def new
    authorize SupplierPayment

    # Session'daki veriyi alarak boş formu önceden doldur
    @payment = @supplier.supplier_payments.new(session[:temp_supplier_payment_data] || {})

    # Dosya imzasını formda (hidden_field) kullanmak için değişkene al
    @pdf_signed_id = session[:supplier_pdf_signed_id]

    # Sayfa yenilendiğinde eski veriler tekrar formda belirmesin diye temizle
    session.delete(:temp_supplier_payment_data)
  end

  # 3. ADIM: Kaydetme (Senin orijinal metodun + PDF iliştirme)
  def create
    authorize SupplierPayment
    @payment = @supplier.supplier_payments.new(payment_params)
    @payment.user = current_user

    if @payment.save
      # Formdan gizli bir PDF imzası geldiyse, dosyayı bu tedarikçi ödemesine bağla
      if params[:pdf_signed_id].present?
        # NOT: SupplierPayment modelinde `has_one_attached :receipt` (veya adını ne koyduysan) tanımlı olmalı
        @payment.receipt.attach(params[:pdf_signed_id])
        session.delete(:supplier_pdf_signed_id) # İşlem bitti, session'ı temizle
      end

      redirect_to supplier_path(@supplier), notice: "Ödeme kaydedildi."
    else
      # Hata durumunda formu baştan çizdir ki kullanıcının girdiği diğer veriler kaybolmasın
      @pdf_signed_id = params[:pdf_signed_id]
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    payment = @supplier.supplier_payments.find(params[:id])
    authorize payment
    payment.destroy
    redirect_to supplier_path(@supplier), notice: "Ödeme silindi."
  end

  private
    def set_supplier
      @supplier = Supplier.find(params[:supplier_id])
    end

    def payment_params
      # Burada sadece supplier modeline özel alanlar var (payment_method yok mesela)
      params.expect(supplier_payment: [ :amount, :paid_at, :note ])
    end
end
