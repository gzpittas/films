Rails.application.routes.draw do
  # This single line creates all the standard routes for a production resource.
  resources :productions

  # Defines the root path route ("/")
  root "productions#index"
end
