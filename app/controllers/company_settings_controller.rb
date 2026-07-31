# Firma yöneticisinin KENDİ firmasının marka/adres/vergi bilgilerini
# düzenlediği ekran (bkz. CompaniesController — platform süper admin'inin
# TÜM firmaları yönettiği, ayrı ve farklı yetkili ekran).
class CompanySettingsController < ApplicationController
  after_action :verify_authorized

  def edit
    @company = authorize current_company
  end

  def update
    @company = authorize current_company

    if @company.update(company_params)
      redirect_to edit_company_settings_path, notice: "Firma bilgileri güncellendi."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def company_params
      params.expect(company: [ :name, :slogan, :address, :phone, :website, :email, :tax_number, :tax_office, :logo ])
    end
end
