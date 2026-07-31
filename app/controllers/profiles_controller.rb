# Giriş yapmış herhangi bir kullanıcının (role farketmeksizin) KENDİ ad/
# e-posta/şifresini düzenlediği ekran — CompanySettingsController (firma
# markası, sadece admin) ve UsersController (başkalarını yönetme, sadece
# admin) ile karıştırılmamalı.
class ProfilesController < ApplicationController
  def edit
    @user = current_user
  end

  def update
    @user = current_user

    if @user.update(profile_params)
      redirect_to edit_profile_path, notice: "Profiliniz güncellendi."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def profile_params
      permitted = params.expect(user: [ :name, :email_address, :password, :password_confirmation ])
      if permitted[:password].blank?
        permitted.delete(:password)
        permitted.delete(:password_confirmation)
      end
      permitted
    end
end
