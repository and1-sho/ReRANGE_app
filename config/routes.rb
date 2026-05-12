# ============================================================
# ルーティング設定
#
# 「どの URL にアクセスしたらどのコントローラのどのアクションを呼ぶか」を
# 一覧で定義するファイル。
# resources :xxx と書くと CRUD（一覧・詳細・新規・編集・削除）に
# 必要な URL とアクションがまとめて生成される。
# ============================================================
Rails.application.routes.draw do
  # Devise が提供するログイン・登録・パスワードリセットなどの URL を自動生成する
  devise_for :users

  # トレーナー一覧・プロフィール・編集（MVP では全ページリダイレクト）
  resources :trainers, only: [:index, :show, :edit, :update], param: :slug

  # メンバープロフィール・編集（MVP では全ページリダイレクト）
  resources :members, only: [:show, :edit, :update], param: :slug

  # リクエスト（投稿）の CRUD
  # アドバイスはリクエストの子リソースとして入れ子にする（/requests/:request_id/advices/...）
  resources :requests, only: [:index, :show, :new, :create, :edit, :update, :destroy] do
    collection { post :polish }   # AI 文章整え（POST /requests/polish）
    resources :advices, only: [:new, :create, :edit, :update, :destroy] do
      collection { post :polish } # AI 文章整え（POST /requests/:request_id/advices/polish）
    end
  end

  # 取引（有料アドバイス）の管理（MVP では全ページリダイレクト）
  resources :transactions, only: [:index, :show] do
    member do
      patch :deliver   # トレーナーが納品する
      patch :complete  # メンバーが完了確認する
    end
  end

  # 通知一覧（MVP ではリダイレクト）
  resources :notifications, only: [:index]

  # MVP ver.0.1.0: paid_advice_requests へのアクセスをブロック（Stripe コールバック含む）
  # /paid_advice_requests への GET は一覧にリダイレクト
  get "paid_advice_requests",         to: redirect("/requests")
  # Stripe 決済後のコールバック先（MVP では機能しないがルートは残す）
  get "paid_advice_requests/success", to: "paid_advice_requests#success", as: :paid_advice_requests_success
  get "paid_advice_requests/cancel",  to: "paid_advice_requests#cancel",  as: :paid_advice_requests_cancel

  # トップページ（ログイン前はランディング、ログイン後はリクエスト一覧へ）
  root "home#index"

  # Rails のヘルスチェック用エンドポイント（デプロイ先のロードバランサーが使う）
  get "up" => "rails/health#show", as: :rails_health_check
end
