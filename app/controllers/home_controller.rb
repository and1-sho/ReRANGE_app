class HomeController < ApplicationController
  def index
    # ログイン済みユーザーはダッシュボードをホームとして扱う
    redirect_to dashboard_path if user_signed_in?
  end
end
