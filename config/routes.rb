Rails.application.routes.draw do
  get 'home/index'
  get 'advices/new'
  get 'advices/create'
  get 'requests/index'
  get 'requests/show'
  get 'requests/new'
  get 'requests/create'
  devise_for :users

  resources :requests, only:[:index, :show, :new, :create] do
    resource :advice, only:[:new, :create]
  end

  # トップページ
  root "home#index"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
