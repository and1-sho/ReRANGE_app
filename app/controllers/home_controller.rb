class HomeController < ApplicationController
  def index
    # ログイン済みユーザーは一覧をホームとして扱う
    redirect_to requests_path if user_signed_in?
  end
end
