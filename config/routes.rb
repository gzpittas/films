# config/routes.rb
Rails.application.routes.draw do
  root 'productions#index'
  
  resources :productions do
    collection do
      get :export_emails
      get :export_phones
    end
  end
  
  resources :companies, only: [:index, :show]
  resources :people, only: [:index, :show]
  
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end