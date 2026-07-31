class PurchaseInvoicesController < ApplicationController
  SORT_COLUMNS = %w[invoice_number invoice_date status].freeze

  before_action :set_purchase_invoice, only: %i[ edit update destroy approve items receipt ]
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  def index
    authorize PurchaseInvoice
    @purchase_invoices = paginate(filtered_and_sorted(policy_scope(PurchaseInvoice)).includes(:supplier))
  end

  def export_pdf
    authorize PurchaseInvoice, :index?
    invoices = filtered_and_sorted(policy_scope(PurchaseInvoice)).includes(:supplier, :purchase_invoice_lines)

    rows = invoices.map do |invoice|
      [
        invoice.invoice_number,
        invoice.supplier.name,
        invoice.invoice_date.strftime("%d.%m.%Y"),
        invoice.approved? ? "Onaylandı" : "Beklemede",
        "#{ActiveSupport::NumberHelper.number_to_delimited(invoice.purchase_invoice_lines.sum(&:total_with_vat).round(2), delimiter: ".", separator: ",")} ₺"
      ]
    end

    pdf = Pdf::ListReportGenerator.call(
      title: "Alış Faturaları",
      headers: [ "Fatura No", "Tedarikçi", "Tarih", "Durum", "Toplam Tutar" ],
      rows: rows
    )
    send_data pdf, filename: "alis-faturalari.pdf", type: "application/pdf", disposition: "inline"
  end

  def export_csv
    authorize PurchaseInvoice, :index?
    invoices = filtered_and_sorted(policy_scope(PurchaseInvoice)).includes(:supplier, :purchase_invoice_lines)

    csv = CSV.generate(headers: true) do |csv|
      csv << [ "Fatura No", "Tedarikçi", "Tarih", "Durum", "Toplam Tutar" ]
      invoices.each do |invoice|
        csv << [
          invoice.invoice_number,
          invoice.supplier.name,
          invoice.invoice_date.strftime("%d.%m.%Y"),
          invoice.approved? ? "Onaylandı" : "Beklemede",
          invoice.purchase_invoice_lines.sum(&:total_with_vat).round(2)
        ]
      end
    end
    send_data csv, filename: "alis-faturalari.csv", type: "text/csv", disposition: "attachment"
  end

  def new
    @purchase_invoice = authorize PurchaseInvoice.new
  end

  # e-Fatura/e-Arşiv XML (UBL) içe aktarma
  def create
    authorize PurchaseInvoice
    file = params.dig(:purchase_invoice, :ubl_file)

    if file.blank?
      @purchase_invoice = PurchaseInvoice.new
      @purchase_invoice.errors.add(:base, "Lütfen bir XML dosyası seçin.")
      return render :new, status: :unprocessable_entity
    end

    begin
      @purchase_invoice = Invoices::UblImporter.new(file.read, created_by: current_user).call
      redirect_to edit_purchase_invoice_path(@purchase_invoice), notice: "Fatura içe aktarıldı. Eşleşmemiş satırları eşleştirip onaylayın."
    rescue Invoices::UblImporter::ParseError, ActiveRecord::RecordInvalid => e
      @purchase_invoice = PurchaseInvoice.new
      @purchase_invoice.errors.add(:base, e.message)
      render :new, status: :unprocessable_entity
    end
  end

  # Taranmış/PDF fatura içe aktarma
  def create_pdf
    authorize PurchaseInvoice, :create?
    @suppliers = Supplier.order(:name)
    file = params.dig(:purchase_invoice, :pdf_file)

    if file.blank?
      @purchase_invoice = PurchaseInvoice.new
      @purchase_invoice.errors.add(:base, "Lütfen bir PDF dosyası seçin.")
      return render :new_manual, status: :unprocessable_entity
    end

    begin
      bytes = file.read
      @data = Invoices::PdfImporter.new(bytes).extract
      @pdf_blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(bytes), filename: file.original_filename.presence || "belge.pdf", content_type: "application/pdf")
      @matched_supplier = find_matching_supplier(@data[:supplier])
      render :review_pdf
    rescue Invoices::PdfImporter::ParseError => e
      @purchase_invoice = PurchaseInvoice.new
      @purchase_invoice.errors.add(:base, e.message)
      render :new_manual, status: :unprocessable_entity
    end
  end

  # Önizleme ekranında kullanıcı tarafından gözden geçirilmiş veri kaydedilir
  def confirm_pdf
    authorize PurchaseInvoice, :create?
    data = review_params
    pdf_blob = ActiveStorage::Blob.find_signed(params.dig(:purchase_invoice, :pdf_blob_signed_id))

    begin
      @purchase_invoice = Invoices::PdfImporter.new(created_by: current_user).persist(data)
      @purchase_invoice.source_pdfs.attach(pdf_blob) if pdf_blob
      redirect_to edit_purchase_invoice_path(@purchase_invoice), notice: "Fatura oluşturuldu. Eşleşmemiş satırları eşleştirip onaylayın."
    rescue Invoices::PdfImporter::ParseError, ActiveRecord::RecordInvalid => e
      @data = data
      @pdf_blob = pdf_blob
      @matched_supplier = find_matching_supplier(data[:supplier])
      flash.now[:alert] = "Kaydedilemedi: #{e.message}"
      render :review_pdf, status: :unprocessable_entity
    end
  end

  def new_manual
    @purchase_invoice = authorize PurchaseInvoice.new(invoice_date: Date.current), :create?
    @suppliers = Supplier.order(:name)
  end

  # Elle fatura girişi (DÜZELTİLDİ: original_document eklendi)
  def create_manual
    authorize PurchaseInvoice, :create?
    @suppliers = Supplier.order(:name)

    supplier = resolve_supplier
    unless supplier
      @purchase_invoice = PurchaseInvoice.new(
        invoice_number: manual_invoice_params[:invoice_number],
        invoice_date: manual_invoice_params[:invoice_date],
        original_document: manual_invoice_params[:original_document]
      )
      @purchase_invoice.errors.add(:base, "Tedarikçi seçin ya da yeni tedarikçi adı girin.")
      return render :new_manual, status: :unprocessable_entity
    end

    @purchase_invoice = PurchaseInvoice.new(
      invoice_number: manual_invoice_params[:invoice_number].presence || "OTO-#{Time.current.to_i}",
      invoice_date: manual_invoice_params[:invoice_date].presence || Date.current,
      original_document: manual_invoice_params[:original_document] # Dosya kaydı eklendi
    )
    @purchase_invoice.supplier = supplier
    @purchase_invoice.created_by = current_user

    if @purchase_invoice.save
      redirect_to items_purchase_invoice_path(@purchase_invoice), notice: "Fatura oluşturuldu. Şimdi ürünleri ekleyin."
    else
      render :new_manual, status: :unprocessable_entity
    end
  end

  def items
    @products = Product.order(:name)
    @categories = Category.order(:name)
  end

  def import_lines_pdf
    @purchase_invoice = PurchaseInvoice.find(params[:id])
    authorize @purchase_invoice, :update?
    file = params.dig(:purchase_invoice, :pdf_file)

    if file.blank?
      return redirect_to items_purchase_invoice_path(@purchase_invoice), alert: "Lütfen bir PDF dosyası seçin."
    end

    begin
      bytes = file.read
      @data = Invoices::PdfImporter.new(bytes).extract
      @pdf_blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(bytes), filename: file.original_filename.presence || "belge.pdf", content_type: "application/pdf")
      render :review_import_lines
    rescue Invoices::PdfImporter::ParseError => e
      redirect_to items_purchase_invoice_path(@purchase_invoice), alert: e.message
    end
  end

  def confirm_import_lines
    @purchase_invoice = PurchaseInvoice.find(params[:id])
    authorize @purchase_invoice, :update?
    raw = params.require(:purchase_invoice).permit(:pdf_blob_signed_id, lines: [ :code, :name, :quantity, :unit_price, :vat_rate ])
    lines = (raw[:lines] || []).map { |line| line.to_h.symbolize_keys }

    begin
      Invoices::PdfImporter.new(created_by: current_user).persist_lines(@purchase_invoice, lines)
      blob = ActiveStorage::Blob.find_signed(raw[:pdf_blob_signed_id])
      @purchase_invoice.source_pdfs.attach(blob) if blob
      redirect_to items_purchase_invoice_path(@purchase_invoice), notice: "Satırlar eklendi."
    rescue Invoices::PdfImporter::ParseError, ActiveRecord::RecordInvalid => e
      @data = { lines: lines }
      @pdf_blob = ActiveStorage::Blob.find_signed(raw[:pdf_blob_signed_id])
      flash.now[:alert] = "Eklenemedi: #{e.message}"
      render :review_import_lines, status: :unprocessable_entity
    end
  end

  def edit
    @products = Product.order(:name)
    @suppliers = Supplier.order(:name)
  end

  def receipt
    pdf = Pdf::ReceiptGenerator.call(
      title: "Alış Faturası",
      doc_number: @purchase_invoice.invoice_number,
      doc_date: @purchase_invoice.invoice_date,
      status_label: @purchase_invoice.approved? ? "Onaylandı" : "Beklemede",
      counterparty_label: "Tedarikçi",
      counterparty_name: @purchase_invoice.supplier.name,
      lines: @purchase_invoice.purchase_invoice_lines.includes(:product).filter_map { |line|
        next unless line.product

        {
          name: line.product.name,
          quantity: line.quantity,
          unit_label: line.product.unit_label,
          unit_price: line.unit_price,
          vat_rate: line.vat_rate,
          total_with_vat: line.total_with_vat
        }
      }
    )
    send_data pdf, filename: "alis-#{@purchase_invoice.invoice_number}.pdf", type: "application/pdf", disposition: "inline"
  end

  def update
    if @purchase_invoice.update(purchase_invoice_params)
      redirect_to edit_purchase_invoice_path(@purchase_invoice), notice: "Fatura güncellendi."
    else
      @products = Product.order(:name)
      @suppliers = Supplier.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def approve
    lines = @purchase_invoice.purchase_invoice_lines.includes(:product).to_a
    supplier = @purchase_invoice.supplier
    @purchase_invoice.approve!(user: current_user)
    summary = lines.map { |l| "#{l.product.name}: stok şimdi #{l.product.reload.stock_quantity}" }.join(" · ")
    redirect_to purchase_invoices_path, notice: "Fatura onaylandı, stok güncellendi → #{summary} · #{supplier.name} cari hesabına borç eklendi, kalan borç: #{supplier.reload.balance} ₺"
  rescue ActiveRecord::RecordInvalid, RuntimeError => e
    fallback_path = @purchase_invoice.needs_line_matching? ? edit_purchase_invoice_path(@purchase_invoice) : items_purchase_invoice_path(@purchase_invoice)
    redirect_to fallback_path, alert: "Onaylanamadı: #{e.message}"
  end

  def destroy
    @purchase_invoice.destroy
    redirect_to purchase_invoices_path, notice: "Fatura silindi."
  end

  private
    def set_purchase_invoice
      @purchase_invoice = authorize PurchaseInvoice.find(params[:id])
    end

    def filtered_and_sorted(scope)
      scope = scope.joins(:supplier).where("invoice_number ILIKE ? OR suppliers.name ILIKE ?", "%#{params[:q]}%", "%#{params[:q]}%") if params[:q].present?
      scope = scope.where(status: params[:status]) if PurchaseInvoice.statuses.key?(params[:status])
      scope = scope.where("invoice_date >= ?", Date.parse(params[:from])) if params[:from].present?
      scope = scope.where("invoice_date <= ?", Date.parse(params[:to])) if params[:to].present?

      if SORT_COLUMNS.include?(params[:sort])
        scope.order(params[:sort] => sort_direction)
      else
        scope.order(created_at: :desc)
      end
    rescue ArgumentError
      scope.order(created_at: :desc)
    end

    def sort_direction
      params[:direction] == "desc" ? :desc : :asc
    end

    def purchase_invoice_params
      params.expect(purchase_invoice: [ :supplier_id, :invoice_number, :original_document, :invoice_date, purchase_invoice_lines_attributes: [ [ :id, :product_id ] ] ])
    end

    # DÜZELTİLDİ: :original_document için izin eklendi
    def manual_invoice_params
      params.fetch(:purchase_invoice, {}).permit(
        :invoice_number,
        :invoice_date,
        :supplier_id,
        :new_supplier_name,
        :new_supplier_tax_number,
        :original_document
      )
    end

    def resolve_supplier
      if params.dig(:purchase_invoice, :supplier_id).present?
        Supplier.find_by(id: params[:purchase_invoice][:supplier_id])
      elsif params.dig(:purchase_invoice, :new_supplier_name).present?
        Supplier.create(
          name: params[:purchase_invoice][:new_supplier_name],
          tax_number: params[:purchase_invoice][:new_supplier_tax_number].presence
        )
      end
    end

    def review_params
      raw = params.require(:purchase_invoice).permit(
        :invoice_number, :invoice_date,
        supplier: [ :name, :tax_number, :tax_office, :address, :phone ],
        lines: [ :code, :name, :quantity, :unit_price, :vat_rate ]
      )

      {
        invoice_number: raw[:invoice_number],
        invoice_date: raw[:invoice_date],
        supplier: (raw[:supplier] || {}).to_h.symbolize_keys,
        lines: (raw[:lines] || []).map { |line| line.to_h.symbolize_keys }
      }
    end

    def find_matching_supplier(supplier_data)
      return nil unless supplier_data
      tax_number = supplier_data[:tax_number].to_s.strip.presence
      return Supplier.find_by(tax_number: tax_number) if tax_number
      name = supplier_data[:name].to_s.strip.presence
      Supplier.find_by("lower(name) = ?", name.downcase) if name
    end
end
