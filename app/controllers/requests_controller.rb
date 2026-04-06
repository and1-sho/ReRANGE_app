class RequestsController < ApplicationController

  # ログインしていない人はアクセスできない設定
  before_action :authenticate_user!
  # memberかをチェックする設定
  before_action :ensure_member!, only: [:new, :create]
  # リクエストをセットする設定
  before_action :set_request, only: [:show]
  #　他人のリクエストを見れないようにする設定（URL直打ち）
  before_action :authorize_request_access!, only: [:show]

  def index
    if current_user.member?
      @requests = current_user.requests
    elsif current_user.coach?
      @requests = Request.all
    end
  end

  def show
  end

  def new
    @request = Request.new
  end

  def create
    @request = current_user.requests.build(request_params)

    if @request.save
      redirect_to requests_path, notice: "作成しました"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def request_params
    params.require(:request).permit(:title, :body)
  end

  def ensure_member!
    redirect_to requests_path, alert: "メンバーのみリクエストを作成できます" unless current_user.member?
  end

  def set_request
    @request = Request.find(params[:id])
  end

  def authorize_request_access!
    return if current_user.coach?
    return if @request.user_id == current_user.id
    redirect_to requests_path, alert: "このリクエストを表示する権限がありません"
  end

end
