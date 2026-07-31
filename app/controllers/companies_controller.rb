class CompaniesController < ApplicationController
  after_action :verify_authorized, except: :stop_impersonating
  after_action :verify_policy_scoped, only: :index

  # Platform sahibinin (super_admin) tüm firmaları (müşterileri) gördüğü liste.
  def index
    authorize Company, :index?
    @companies = policy_scope(Company).order(:name)
  end

  # Yeni bir firma (müşteri) ve ilk yönetici kullanıcısını birlikte oluşturur.
  def new
    authorize Company, :create?
    @company = Company.new
    @admin = User.new
  end

  def create
    authorize Company, :create?
    @company = Company.new(company_params)
    @admin = User.new(admin_params.merge(role: :admin))

    Company.transaction do
      @company.save!
      @admin.company = @company
      @admin.save!
    end
    ActsAsTenant.with_tenant(@company) { Companies::SeedDefaults.call }
    ConfirmationsMailer.confirm(@admin).deliver_later

    redirect_to companies_path, notice: "\"#{@company.name}\" oluşturuldu. #{@admin.email_address} adresine gönderilen bağlantıyla hesabını onayladıktan sonra giriş yapabilir."
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  # Platform süper admin'inin HERHANGİ bir firmayı (kendisininki dahil)
  # düzenlemesi — firma kendi admin'i için bkz. CompanySettingsController.
  def edit
    @company = authorize Company.find(params[:id])
  end

  def update
    @company = authorize Company.find(params[:id])

    if @company.update(company_params)
      redirect_to companies_path, notice: "\"#{@company.name}\" güncellendi."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Firmayı ve TÜM verilerini (kullanıcılar, müşteriler, ürünler, satışlar,
  # faturalar vb. — bkz. Company modelindeki has_many sırası) kalıcı olarak
  # siler. ActsAsTenant.with_tenant ile sarılıyor çünkü silinen firma, işlemi
  # yapan süper admin'in KENDİ firması olmayabilir — sarılmazsa acts_as_tenant
  # varsayılan kapsamı devreye girip yanlış (ya da hiç) kaydı silmeye çalışır.
  def destroy
    @company = authorize Company.find(params[:id])
    name = @company.name

    ActsAsTenant.with_tenant(@company) { @company.destroy }

    redirect_to companies_path, notice: "\"#{name}\" ve tüm verileri silindi."
  end

  # Süper admin'in bir firmanın verilerini/ekranlarını kendi hesabından
  # çıkmadan görüp düzeltebilmesi için "içine geçmesi" — kullanıcının kendi
  # company_id'si değişmez, sadece görüntülenen iş verisi (bkz.
  # ApplicationController#effective_company) geçici olarak değişir.
  def impersonate
    company = authorize Company.find(params[:id]), :impersonate?
    session[:impersonated_company_id] = company.id
    redirect_to root_path, notice: "\"#{company.name}\" firmasına geçtiniz."
  end

  def stop_impersonating
    session.delete(:impersonated_company_id)
    redirect_to companies_path, notice: "Kendi firmanıza döndünüz."
  end

  private
    def company_params
      params.expect(company: [ :name, :slogan, :address, :phone, :website, :email, :tax_number, :tax_office, :logo ])
    end

    def admin_params
      params.expect(admin: [ :name, :email_address, :password, :password_confirmation ])
    end
end
