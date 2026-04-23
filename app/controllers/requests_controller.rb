class RequestsController < ApplicationController
  POLISH_MAX_ATTEMPTS = 2

  # ログインしていない人はアクセスできない設定
  before_action :authenticate_user!
  # memberかをチェックする設定
  before_action :ensure_member!, only: [:new, :create, :edit, :update, :destroy, :polish]
  # リクエストをセットする設定
  before_action :set_request, only: [:show, :edit, :update, :destroy]
  # 閲覧権限: 公開リクエストはログイン全員、指定トレーナー宛は投稿者とそのトレーナーのみ（show）
  before_action :authorize_request_access!, only: [:show]
  # リクエスト詳細を開いたら、このリクエストに紐づく自分宛未読通知を既読にする
  before_action :mark_request_notifications_as_read!, only: [:show]
  # 編集・削除はリクエストの投稿者本人のみ（member 同士のなりすまし防止）
  before_action :authorize_request_owner!, only: [:edit, :update, :destroy]
  before_action :prepare_request_polish_session!, only: [:new, :create, :edit, :update]

  def index
    @requests = if current_user.member?
                  Request.on_public_feed
                elsif current_user.trainer?
                  base = Request.on_public_feed
                  if params[:filter] == "advised_by_me"
                    base.joins(:advice).where(advices: { user_id: current_user.id })
                  else
                    base
                  end
                end
    @requests = @requests.includes(:user, video_attachment: :blob, video_thumbnail_attachment: :blob)
                           .order(created_at: :desc)
  end

  def show
  end

  def new
    @request = Request.new
  end

  def create
    @request = current_user.requests.build(request_params)
    draft_token = params[:request_polish_draft_token].to_s

    if @request.save
      clear_polish_attempts!(draft_token)
      enqueue_video_thumbnail_job_if_video_attached!(@request)
      notify_trainers_new_request!
      redirect_to requests_path, notice: "作成しました"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    old_video_key = @request.video.attached? ? @request.video.blob.key : nil
    handle_video_removal_on_update!

    if @request.update(request_params)
      clear_polish_attempts!(params[:request_polish_draft_token].to_s)
      sync_video_thumbnail_after_update!(old_video_key)
      notify_advising_trainer_request_body_updated!
      # /requests/:idにリダイレクトするってこと（つまりrequests#showに移動する）
      redirect_to @request, notice: "更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @request.destroy
    redirect_to requests_path, notice: "削除しました"
  end

  def polish
    draft_token = params[:draft_token].to_s
    return render json: { error: "整形セッションが無効です。再読み込みしてください。" }, status: :unprocessable_entity if draft_token.blank?

    if remaining_polish_attempts(draft_token) <= 0
      return render json: { error: "文章を整える操作は2回までです", remaining_attempts: 0 }, status: :unprocessable_entity
    end

    body = params[:body].to_s.strip
    return render json: { error: "本文を入力してください", remaining_attempts: remaining_polish_attempts(draft_token) }, status: :unprocessable_entity if body.blank?

    polisher = ::RequestTextPolisher.new(body: body)
    proposal = polisher.call
    increment_polish_attempts!(draft_token)
    render json: proposal.merge(remaining_attempts: remaining_polish_attempts(draft_token)), status: :ok
  rescue RequestTextPolisher::PolishError => e
    render json: { error: e.message, remaining_attempts: remaining_polish_attempts(draft_token) }, status: :unprocessable_entity
  end

  private

  def prepare_request_polish_session!
    @request_polish_draft_token = params[:request_polish_draft_token].presence || SecureRandom.uuid
    @remaining_polish_attempts = remaining_polish_attempts(@request_polish_draft_token)
  end

  def request_params
    permitted = [:title, :body, :video]
    permitted << :directed_to_trainer_id if action_name == "create"
    params.require(:request).permit(*permitted)
  end

  def polish_attempts_store
    raw = session[:request_polish_attempts]
    store = raw.is_a?(Hash) ? raw : {}
    session[:request_polish_attempts] = store
    store
  end

  def polish_attempts(draft_token)
    polish_attempts_store[draft_token].to_i
  end

  def remaining_polish_attempts(draft_token)
    [POLISH_MAX_ATTEMPTS - polish_attempts(draft_token), 0].max
  end

  def increment_polish_attempts!(draft_token)
    polish_attempts_store[draft_token] = polish_attempts(draft_token) + 1
  end

  def clear_polish_attempts!(draft_token)
    return if draft_token.blank?

    polish_attempts_store.delete(draft_token)
  end

  # 動画のみ削除（新しいファイルを選んだ場合は update 内の attach で差し替え）
  def handle_video_removal_on_update!
    return unless params.dig(:request, :remove_video) == "1"
    return if params.dig(:request, :video).present?

    @request.video_thumbnail.purge if @request.video_thumbnail.attached?
    @request.video.purge if @request.video.attached?
  end

  def enqueue_video_thumbnail_job_if_video_attached!(request)
    VideoThumbnailJob.perform_later("Request", request.id) if request.video.attached?
  end

  def sync_video_thumbnail_after_update!(old_video_key)
    unless @request.video.attached?
      @request.video_thumbnail.purge if @request.video_thumbnail.attached?
      return
    end

    new_key = @request.video.blob.key
    VideoThumbnailJob.perform_later("Request", @request.id) if old_video_key != new_key
  end

  def ensure_member!
    return if current_user.member?

    message = "メンバーのみリクエストを作成できます"
    if request.format.json?
      render json: { error: message }, status: :forbidden
    else
      redirect_to requests_path, alert: message
    end
  end

  def set_request
    scope = Request
    if action_name == "show"
      scope = Request.includes(
        :user,
        video_attachment: :blob,
        advice: [:user, video_attachment: :blob]
      )
    end
    @request = scope.find(params[:id])
  end

  def authorize_request_access!
    return if @request.visible_to?(current_user)

    redirect_to requests_path, alert: "このリクエストを表示する権限がありません"
  end

  # 自分の投稿以外は編集・削除はできない
  def authorize_request_owner!
    return if @request.user_id == current_user.id

    redirect_to requests_path, alert: "このリクエストを編集・削除する権限がありません"
  end

  # このリクエストに紐づく、ログイン中ユーザー宛の未読通知を既読にする
  def mark_request_notifications_as_read!
    current_user.notifications.unread.where(request_id: @request.id).update_all(read_at: Time.current)
  end

  # 公開リクエストは全トレーナーへ通知。指定トレーナー宛はそのトレーナーのみ
  def notify_trainers_new_request!
    if @request.directed_to_trainer_id.present?
      trainer = User.trainer.find_by(id: @request.directed_to_trainer_id)
      return if trainer.blank?

      Notification.create!(
        user: trainer,
        request: @request,
        kind: "direct_request",
        message: "あなた宛のリクエスト「#{@request.title}」が届きました"
      )
    else
      message = "新しいリクエスト「#{@request.title}」が投稿されました"
      User.trainer.find_each do |trainer|
        Notification.create!(
          user: trainer,
          request: @request,
          kind: "new_request",
          message: message
        )
      end
    end
  end

  # 本文が更新されたら、アドバイス済みのトレーナーにだけ通知する（タイトルだけの変更では送らない）
  def notify_advising_trainer_request_body_updated!
    # .saved_change_to_body?はカラムを作った時に自動生成されるメソッド
    return unless @request.saved_change_to_body?
    return if @request.advice.blank?

    Notification.create!(
      user: @request.advice.user,
      request: @request,
      kind: "request_body_updated",
      message: "リクエスト「#{@request.title}」の本文が更新されました"
    )
  end

end
