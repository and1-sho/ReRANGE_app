class AdvicesController < ApplicationController
  POLISH_MAX_ATTEMPTS = 2

  # ログインしていない人はアクセスできない設定
  before_action :authenticate_user!
  # URL の request_id からリクエストを読み込み、@request に入れる設定
  before_action :set_request
  # トレーナーかをチェックする設定
  before_action :ensure_trainer!, only: [:new, :create, :edit, :update, :destroy, :polish]
  before_action :authorize_advice_polish!, only: [:polish]
  # 指定トレーナー宛はそのトレーナーのみアドバイス可能
  before_action :authorize_designated_trainer_for_direct_request!, only: [:new, :create]
  # まだアドバイスが無いリクエストだけ new / create できる（二重投稿を防ぐ）
  before_action :ensure_no_advice_yet!, only: [:new, :create]
  # アドバイスを @advice にセットする設定（edit / update / destroy）
  before_action :set_advice, only: [:edit, :update, :destroy]
  # 編集・削除はアドバイスを書いたトレーナー本人のみ
  before_action :authorize_advice_owner!, only: [:edit, :update, :destroy]

  def new
    @advice = Advice.new
    @advice_polish_draft_token = SecureRandom.uuid
    @remaining_polish_attempts = remaining_advice_polish_attempts(@advice_polish_draft_token)
  end

  def create
    @advice = @request.build_advice(advice_params)
    @advice.user = current_user
    draft_token = params[:advice_polish_draft_token].to_s

    if @advice.save
      clear_advice_polish_attempts!(draft_token)
      enqueue_advice_video_thumbnail_job_if_attached!(@advice)
      notify_request_owner_advice_received!
      redirect_to request_path(@request), notice: "アドバイスを投稿しました"
    else
      @advice_polish_draft_token = params[:advice_polish_draft_token].presence || SecureRandom.uuid
      @remaining_polish_attempts = remaining_advice_polish_attempts(@advice_polish_draft_token)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @advice_polish_draft_token = SecureRandom.uuid
    @remaining_polish_attempts = remaining_advice_polish_attempts(@advice_polish_draft_token)
  end

  def update
    old_video_key = @advice.video.attached? ? @advice.video.blob.key : nil
    handle_advice_video_removal_on_update!
    draft_token = params[:advice_polish_draft_token].to_s

    if @advice.update(advice_params)
      clear_advice_polish_attempts!(draft_token)
      sync_advice_video_thumbnail_after_update!(old_video_key)
      redirect_to request_path(@request), notice: "アドバイスを更新しました"
    else
      @advice_polish_draft_token = params[:advice_polish_draft_token].presence || SecureRandom.uuid
      @remaining_polish_attempts = remaining_advice_polish_attempts(@advice_polish_draft_token)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @advice.destroy
    redirect_to request_path(@request), notice: "アドバイスを削除しました"
  end

  def polish
    draft_token = params[:draft_token].to_s
    return render json: { error: "整形セッションが無効です。再読み込みしてください。" }, status: :unprocessable_entity if draft_token.blank?

    if remaining_advice_polish_attempts(draft_token) <= 0
      return render json: { error: "文章を整える操作は2回までです", remaining_attempts: 0 }, status: :unprocessable_entity
    end

    body = params[:body].to_s.strip
    return render json: { error: "本文を入力してください", remaining_attempts: remaining_advice_polish_attempts(draft_token) }, status: :unprocessable_entity if body.blank?

    polisher = ::AdviceTextPolisher.new(body: body)
    proposal = polisher.call
    increment_advice_polish_attempts!(draft_token)
    render json: proposal.merge(remaining_attempts: remaining_advice_polish_attempts(draft_token)), status: :ok
  rescue AdviceTextPolisher::PolishError => e
    render json: { error: e.message, remaining_attempts: remaining_advice_polish_attempts(draft_token) }, status: :unprocessable_entity
  end

  private

  # リクエストの投稿者（メンバー）へ「アドバイスが届いた」通知を1件作る
  def notify_request_owner_advice_received!
    Notification.create!(
      user: @request.user,
      request: @request,
      kind: "advice_received",
      message: "「#{@request.title}」にアドバイスが届きました"
    )
  end

  def set_request
    @request = Request.includes(:user, video_attachment: :blob, video_thumbnail_attachment: :blob).find(params[:request_id])
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

  # すでにアドバイスがあるリクエストには新規投稿させない
  def ensure_no_advice_yet!
    return if @request.advice.blank?

    redirect_to request_path(@request), alert: "すでにアドバイスが投稿されています"
  end

  def advice_params
    params.require(:advice).permit(:body, :video)
  end

  def authorize_advice_polish!
    unless current_user.trainer?
      render json: { error: "トレーナーのみアドバイスできます" }, status: :forbidden
      return
    end

    if @request.advice.present?
      return if @request.advice.user_id == current_user.id

      render json: { error: "このアドバイスを整形する権限がありません" }, status: :forbidden
      return
    end

    return unless @request.directed_to_trainer_id.present? && @request.directed_to_trainer_id != current_user.id

    render json: { error: "このリクエストにアドバイスできるのは指定されたトレーナーのみです" }, status: :forbidden
  end

  def advice_polish_attempts_store
    raw = session[:advice_polish_attempts]
    store = raw.is_a?(Hash) ? raw : {}
    session[:advice_polish_attempts] = store
    store
  end

  def advice_polish_attempts(draft_token)
    advice_polish_attempts_store[draft_token].to_i
  end

  def remaining_advice_polish_attempts(draft_token)
    [POLISH_MAX_ATTEMPTS - advice_polish_attempts(draft_token), 0].max
  end

  def increment_advice_polish_attempts!(draft_token)
    advice_polish_attempts_store[draft_token] = advice_polish_attempts(draft_token) + 1
  end

  def clear_advice_polish_attempts!(draft_token)
    return if draft_token.blank?

    advice_polish_attempts_store.delete(draft_token)
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

  def ensure_trainer!
    return if current_user.trainer?

    message = "トレーナーのみアドバイスできます"
    if request.format.json?
      render json: { error: message }, status: :forbidden
    else
      redirect_to requests_path, alert: message
    end
  end

  def authorize_designated_trainer_for_direct_request!
    return if @request.directed_to_trainer_id.blank?
    return if @request.directed_to_trainer_id == current_user.id

    redirect_to request_path(@request), alert: "このリクエストにアドバイスできるのは指定されたトレーナーのみです"
  end
end
