class AdvicesController < ApplicationController

  # ログインしていない人はアクセスできない設定
  before_action :authenticate_user!
  # URL の request_id から相談を読み込み、@request に入れる設定
  before_action :set_request
  # coachかをチェックする設定
  before_action :ensure_coach!, only: [:new, :create, :edit, :update, :destroy]
  # まだアドバイスが無い相談だけ new / create できる（二重投稿を防ぐ）
  before_action :ensure_no_advice_yet!, only: [:new, :create]
  # アドバイスを @advice にセットする設定（edit / update / destroy）
  before_action :set_advice, only: [:edit, :update, :destroy]
  # 編集・削除はアドバイスを書いたコーチ本人のみ
  before_action :authorize_advice_owner!, only: [:edit, :update, :destroy]

  def new
    @advice = Advice.new
  end

  def create
    @advice = @request.build_advice(advice_params)
    @advice.user = current_user

    if @advice.save
      redirect_to request_path(@request), notice: "アドバイスを投稿しました"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @advice.update(advice_params)
      redirect_to request_path(@request), notice: "アドバイスを更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @advice.destroy
    redirect_to request_path(@request), notice: "アドバイスを削除しました"
  end

  private

  def set_request
    @request = Request.find(params[:request_id])
  end

  # アドバイスが無ければ詳細へ戻す
  def set_advice
    @advice = @request.advice
    return if @advice

    redirect_to request_path(@request), alert: "アドバイスがありません"
  end

  # 自分が書いたアドバイス以外は編集・削除できない
  def authorize_advice_owner!
    return if @advice.user_id == current_user.id

    redirect_to request_path(@request), alert: "このアドバイスを編集・削除する権限がありません"
  end

  # すでにアドバイスがある相談には新規投稿させない
  def ensure_no_advice_yet!
    return if @request.advice.blank?

    redirect_to request_path(@request), alert: "すでにアドバイスが投稿されています"
  end

  def advice_params
    params.require(:advice).permit(:body)
  end

  def ensure_coach!
    redirect_to requests_path, alert: "コーチのみアドバイスできます" unless current_user.coach?
  end
end
