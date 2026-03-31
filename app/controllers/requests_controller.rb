class RequestsController < ApplicationController

  # ログインしていない人はアクセスできない設定
  before_action :authenticate_user!
  # memberかをチェックする設定
  before_action :ensure_member!, only: [:new, :create]

  def index
    if current_user.member?
      @requests = current_user.requests
    elsif current_user.coach?
      @requests = Request.all
    end
  end

  def show
    @request = Request.find(params[:id])
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
end
