class CustomerPaymentsController < ApplicationController
  before_action :set_customer
  after_action :verify_authorized

  # 1. ADIM: PDF'in yüklenip Gemini ile okunduğu ara action
  def parse_pdf
    authorize CustomerPayment
    uploaded_file = params[:file]

    if uploaded_file.blank?
      return redirect_to new_customer_customer_payment_path(@customer), alert: "Lütfen bir PDF dosyası seçin."
    end

    bytes = uploaded_file.read
    extracted_data = CustomerPayments::PdfReader.call(bytes)
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(bytes), filename: uploaded_file.original_filename.presence || "dekont.pdf", content_type: "application/pdf")

    session[:temp_payment_data] = extracted_data
    session[:pdf_signed_id] = blob.signed_id

    redirect_to new_customer_customer_payment_path(@customer), notice: "PDF başarıyla okundu. Lütfen bilgileri kontrol edip onaylayın."
  rescue CustomerPayments::PdfReader::ParseError => e
    redirect_to new_customer_customer_payment_path(@customer), alert: e.message
  end

  # 2. ADIM: Kullanıcının onay yapacağı form sayfası
  def new
    authorize CustomerPayment

    # Session'daki veriyle objeyi doldur (yoksa boş hash kullan)
    @payment = @customer.customer_payments.new(session[:temp_payment_data] || {})

    # View'daki hidden_field için ID'yi değişkene al
    @pdf_signed_id = session[:pdf_signed_id]

    # Sayfa yenilendiğinde eski veriler tekrar gelmesin diye session'ı temizle
    session.delete(:temp_payment_data)
  end

  # 3. ADIM: Mevcut create metodunun güncellenmiş hali
  def create
    authorize CustomerPayment
    @payment = @customer.customer_payments.new(payment_params)
    @payment.user = current_user

    if @payment.save
      # Formdan gizli bir PDF imzası geldiyse, bu ödemeye iliştir
      if params[:pdf_signed_id].present?
        # NOT: CustomerPayment modelinde `has_one_attached :receipt` tanımlı olmalı
        @payment.receipt.attach(params[:pdf_signed_id])
        session.delete(:pdf_signed_id) # İşlem bitti, temizle
      end

      redirect_to customer_path(@customer), notice: "Ödeme kaydedildi."
    else
      # DİKKAT: Burada redirect_to yerine render :new kullandık.
      # Çünkü onay sayfasında bir hata çıkarsa, kullanıcının düzelttiği veriler kaybolmasın istiyoruz.
      @pdf_signed_id = params[:pdf_signed_id] # Hata olursa hidden_field boş kalmasın diye tekrar set ediyoruz
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    payment = @customer.customer_payments.find(params[:id])
    authorize payment
    payment.destroy
    redirect_to customer_path(@customer), notice: "Ödeme silindi."
  end

  private
    def set_customer
      @customer = Customer.find(params[:customer_id])
    end

    def payment_params
      params.expect(customer_payment: [ :amount, :paid_at, :payment_method, :note ])
    end
end
