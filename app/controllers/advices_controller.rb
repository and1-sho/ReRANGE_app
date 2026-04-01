class AdvicesController < ApplicationController
  # ログインしていない人はアクセスできない設定
  before_action :authenticate_user!
  # coachかをチェックする設定
  before_action :ensure_coach!, only: [:new, :create]


  def new
    @request = Request.find(params[:request_id])
    @advice = Advice.new
  end

  def create
    @request = Request.find(params[:request_id])
    @advice = @request.build_advice(advice_params)
    @advice.user = current_user

    if @advice.save
      redirect_to request_path(@request), notice: "アドバイスを投稿しました"
    else
      render :new, status: :unprocessable_entity
    end
  end


  private

  def advice_params
    params.require(:advice).permit(:body)
  end

  def ensure_coach!
    redirect_to requests_path, alert: "コーチのみアドバイスできます" unless current_user.coach?
  end
end
