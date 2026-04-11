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
      enqueue_advice_video_thumbnail_job_if_attached!(@advice)
      notify_request_owner_advice_received!
      redirect_to request_path(@request), notice: "アドバイスを投稿しました"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    old_video_key = @advice.video.attached? ? @advice.video.blob.key : nil
    handle_advice_video_removal_on_update!

    if @advice.update(advice_params)
      sync_advice_video_thumbnail_after_update!(old_video_key)
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

  # 相談の投稿者（メンバー）へ「アドバイスが届いた」通知を1件作る
  def notify_request_owner_advice_received!
    Notification.create!(
      user: @request.user,
      request: @request,
      kind: "advice_received",
      message: "「#{@request.title}」にアドバイスが届きました"
    )
  end

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
    params.require(:advice).permit(:body, :video)
  end

  def handle_advice_video_removal_on_update!
    return unless params.dig(:advice, :remove_video) == "1"
    return if params.dig(:advice, :video).present?

    @advice.video_thumbnail.purge if @advice.video_thumbnail.attached?
    @advice.video.purge if @advice.video.attached?
  end

  def enqueue_advice_video_thumbnail_job_if_attached!(advice)
    VideoThumbnailJob.perform_later("Advice", advice.id) if advice.video.attached?
  end

  def sync_advice_video_thumbnail_after_update!(old_video_key)
    unless @advice.video.attached?
      @advice.video_thumbnail.purge if @advice.video_thumbnail.attached?
      return
    end

    new_key = @advice.video.blob.key
    VideoThumbnailJob.perform_later("Advice", @advice.id) if old_video_key != new_key
  end

  def ensure_coach!
    redirect_to requests_path, alert: "コーチのみアドバイスできます" unless current_user.coach?
  end
end
