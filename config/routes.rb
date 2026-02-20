Rails.application.routes.draw do
  resource :session
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"

  resources :dashboard, only: [ :index ]

  resources :clients, only: [ :new, :edit, :update ] do
    post 'create', on: :collection
    get 'show', on: :collection, as: 'show'
    get 'find', on: :collection
    get 'info', on: :collection
    get 'visit_history', on: :collection
    get 'intake_form', on: :collection
    get 'tefap_attestation', on: :collection
  end

  resources :visits, only: [ :create, :index ] do
    get 'daily_signin', on: :collection
  end

  resources :users, only: [ :new, :create ]
end
