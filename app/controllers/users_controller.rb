class UsersController < ApplicationController
  SORT_COLUMNS = %w[name email_address role].freeze

  before_action :set_user, only: %i[ edit update destroy ]
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  def index
    authorize User
    # Super admin ise policy_scope tümünü, firma admin'i ise sadece kendi firmasını getirir
    @users = paginate(filtered_and_sorted(policy_scope(User)))
  end

  def export_csv
    authorize User, :index?
    users = filtered_and_sorted(policy_scope(User))

    csv = CSV.generate(headers: true) do |csv|
      csv << [ "Ad Soyad", "E-posta", "Rol" ]
      users.each do |user|
        csv << [ user.name, user.email_address, { "admin" => "Admin", "depo" => "Depo", "satis" => "Satış" }[user.role] ]
      end
    end
    send_data csv, filename: "kullanicilar.csv", type: "text/csv", disposition: "attachment"
  end

  def new
    @user = authorize User.new
  end

  def create
    # Kullanıcı her zaman o an GÖRÜNTÜLENEN firmaya eklenir (bkz. UserPolicy)
    # — süper admin de dahil. Başka bir firmaya kullanıcı eklemek için önce
    # "Bu Firmaya Geç" ile o firmaya geçmesi gerekir.
    @user = authorize User.new(user_params.merge(company: current_company))

    # Firma yöneticisi (süper admin değilse) formdan "admin" rolü gönderilse
    # bile bunu "depo"ya düşürürüz — kendini/başkasını yönetici yapamaz.
    @user.role = "depo" if @user.admin? && !current_user.super_admin?

    if @user.save
      ConfirmationsMailer.confirm(@user).deliver_later
      redirect_to users_path, notice: "Kullanıcı oluşturuldu. Hesabını onaylaması için bir e-posta gönderildi."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    safe_params = user_update_params

    # Firma yöneticisi mevcut bir çalışanı güncellerken onu "admin" yapmaya
    # çalışırsa, bu isteği parametrelerden sil.
    if !current_user.super_admin? && safe_params[:role] == "admin"
      safe_params.delete(:role)
    end

    if @user.update(safe_params)
      redirect_to users_path, notice: "Kullanıcı güncellendi."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @user.destroy
    redirect_to users_path, notice: "Kullanıcı silindi."
  rescue ActiveRecord::DeleteRestrictionError
    redirect_to users_path, alert: "Bu kullanıcıya bağlı kayıtlar var, silinemez."
  end

  private
    def set_user
      @user = authorize User.find(params[:id])
    end

    def sort_direction
      params[:direction] == "desc" ? :desc : :asc
    end

    def filtered_and_sorted(scope)
      scope = scope.where("name ILIKE ? OR email_address ILIKE ?", "%#{params[:q]}%", "%#{params[:q]}%") if params[:q].present?
      scope = scope.where(role: params[:role]) if User.roles.key?(params[:role])

      SORT_COLUMNS.include?(params[:sort]) ? scope.order(params[:sort] => sort_direction) : scope.order(:email_address)
    end

    def user_params
      # company_id kabul edilmiyor — kullanıcı her zaman o an görüntülenen
      # firmaya atanır (bkz. create).
      params.expect(user: [ :name, :email_address, :password, :password_confirmation, :role ])
    end

    def user_update_params
      permitted = user_params
      if permitted[:password].blank?
        permitted.delete(:password)
        permitted.delete(:password_confirmation)
      end
      permitted
    end
end
