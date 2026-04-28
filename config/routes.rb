Rails.application.routes.draw do
  get 'home/index'
  get 'advices/new'
  get 'advices/create'
  devise_for :users

  # トレーナープロフィール（公開ページ）
  resources :trainers, only: [:index, :show, :edit, :update], param: :slug
  # メンバープロフィール
  resources :members, only: [:show, :edit, :update], param: :slug

  resources :requests, only:[:index, :show, :new, :create, :edit, :update, :destroy] do
    collection do
      post :polish
    end
    resources :advices, only: [:new, :create, :edit, :update, :destroy] do
      collection do
        post :polish
      end
    end
    post "advices/:advice_id/paid_advice_requests", to: "paid_advice_requests#create", as: :advice_paid_advice_requests
  end

  get "paid_advice_requests/success", to: "paid_advice_requests#success", as: :paid_advice_requests_success
  get "paid_advice_requests/cancel", to: "paid_advice_requests#cancel", as: :paid_advice_requests_cancel
  resources :transactions, only: [:index, :show] do
    member do
      patch :deliver
      patch :complete
    end
  end

  resources :notifications, only: [:index]

  # トップページ
  root "home#index"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
