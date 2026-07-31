Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resources :confirmations, param: :token, only: [ :new, :create, :show ]

  resources :categories, except: [ :show ] do
    collection do
      get :new_pdf
      post :new_pdf, action: :create_pdf
      get :export_pdf
      get :export_csv
    end
  end

  resources :category_options, only: [ :index, :create, :destroy ]
  resources :category_option_groups, only: [ :create, :destroy ]

  resources :suppliers do
    member do
      get :statement
    end
    collection do
      get :export_pdf
      get :export_csv
      post :extract_pdf
    end
    # YENİ SİSTEM: :new eklendi ve parse_pdf rotası içeri alındı
    resources :supplier_payments, only: [ :new, :create, :destroy ] do
      collection do
        post :parse_pdf
      end
    end
  end

  resources :customers do
    member do
      get :statement
    end
    collection do
      get :export_pdf
      get :export_csv
      post :extract_pdf
    end
    # YENİ SİSTEM: :new eklendi ve parse_pdf rotası içeri alındı
    resources :customer_payments, only: [ :new, :create, :destroy ] do
      collection do
        post :parse_pdf
      end
    end
  end

  resources :products, except: [ :show ] do
    collection do
      get :export_pdf
      get :export_csv
      post :extract_pdf
    end
  end

  resources :purchase_invoices, except: [ :show ] do
    member do
      patch :approve
      get :items
      get :receipt
      post :import_lines_pdf
      post :confirm_import_lines
    end
    collection do
      get :new_manual
      post :new_manual, action: :create_manual
      post :new_pdf, action: :create_pdf
      post :confirm_pdf
      get :export_pdf
      get :export_csv
    end
    resources :purchase_invoice_lines, only: [ :create, :destroy ], controller: "purchase_invoice_items"
  end

  resources :sales, except: [ :show ] do
    member do
      patch :approve
      get :items
      get :receipt
      post :import_lines_pdf
      post :confirm_import_lines
    end
    collection do
      post :new_pdf, action: :create_pdf
      post :confirm_pdf
      get :export_pdf
      get :export_csv
    end
    resources :sale_lines, only: [ :create, :destroy ], controller: "sale_items"
  end

  resources :stock_movements, only: [ :index ] do
    collection do
      get :export_pdf
      get :export_csv
    end
  end

  resources :stock_adjustments, only: [ :index, :new, :create ] do
    collection do
      get :export_pdf
      get :export_csv
    end
  end

  resources :users, except: [ :show ] do
    collection do
      get :export_csv
    end
  end
  resource :profile, only: [ :edit, :update ]
  resources :support_requests, only: [ :create ]
  resource :company_settings, only: [ :edit, :update ]
  resources :companies, only: [ :index, :new, :create, :edit, :update, :destroy ] do
    member do
      post :impersonate
    end
    collection do
      delete :stop_impersonating
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with nxpo exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  get "dashboard/monthly_report", to: "dashboard#monthly_report", as: :monthly_report
  get "dashboard/summary", to: "dashboard#summary", as: :dashboard_summary

  get "hakkimizda", to: "pages#about", as: :about
  get "platform", to: "pages#platform", as: :platform
  get "cozumler", to: "pages#solutions", as: :solutions
  get "fiyatlandirma", to: "pages#pricing", as: :pricing
  get "destek", to: "pages#support", as: :support
  resources :demo_requests, only: [ :new, :create ]

  get "kvkk", to: "legal#kvkk", as: :kvkk
  get "gizlilik-politikasi", to: "legal#privacy", as: :privacy
  get "kullanim-sartlari", to: "legal#terms", as: :terms

  root "dashboard#index"
end
