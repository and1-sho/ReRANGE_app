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
                  Request.where("directed_to_trainer_id IS NULL OR user_id = ?", current_user.id)
                elsif current_user.trainer?
                  @request_feed_tab = params[:feed] == "direct" ? "direct" : "all"
                  @has_unadvised_direct_requests = Request
                    .where(directed_to_trainer_id: current_user.id)
                    .where.missing(:advices)
                    .exists?
                  base = Request.where("directed_to_trainer_id IS NULL OR directed_to_trainer_id = ?", current_user.id)
                  if params[:filter] == "advised_by_me"
                    base.joins(:advices).where(advices: { user_id: current_user.id }).distinct
                  elsif @request_feed_tab == "direct"
                    base.where(directed_to_trainer_id: current_user.id)
                  else
                    base
                  end
                end
    @requests = @requests.includes(:user, :advices, video_attachment: :blob, video_thumbnail_attachment: :blob)
                           .order(created_at: :desc)
  end

  def show
    if can_current_user_edit_request_inline?
      @editing_request = params[:edit_request] == "1"
      @request_edit_form = @request
      @request_polish_draft_token = request_edit_polish_token(@request)
      @remaining_request_polish_attempts = remaining_polish_attempts(@request_polish_draft_token)
    end

    if can_current_user_edit_advice_inline?
      @editing_advice = params[:edit_advice] == "1"
      @advice_edit_form = current_user_advice_for_request
      @advice_polish_draft_token = advice_edit_polish_token(@advice_edit_form)
      @remaining_advice_polish_attempts = remaining_advice_polish_attempts_for_show(@advice_polish_draft_token)
    end
    if can_current_user_compose_advice_inline?
      @inline_advice = Advice.new
      @inline_advice_polish_draft_token = params[:advice_polish_draft_token].presence || "advice-new-request-#{@request.id}-user-#{current_user.id}"
      @remaining_inline_advice_polish_attempts = remaining_advice_polish_attempts_for_show(@inline_advice_polish_draft_token)
    end
  end

  def new
    @request = Request.new
    @trainers = trainers_for_request_form
  end

  def create
    @request = current_user.requests.build(request_params)
    @request.directed_to_trainer_id = nil if params[:request_visibility].to_s != "private"
    draft_token = params[:request_polish_draft_token].to_s

    if params[:request_visibility].to_s == "private" && @request.directed_to_trainer_id.blank?
      @request.errors.add(:base, "非公開の場合はトレーナーを選択してください")
      @trainers = trainers_for_request_form
      render :new, status: :unprocessable_entity
      return
    end

    if @request.save
      clear_polish_attempts!(draft_token)
      enqueue_video_thumbnail_job_if_video_attached!(@request)
      notify_trainers_new_request!
      redirect_to requests_path, notice: "作成しました"
    else
      @trainers = trainers_for_request_form
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    old_video_key = @request.video.attached? ? @request.video.blob.key : nil
    video_removed_by_user = params.dig(:request, :remove_video) == "1" && params.dig(:request, :video).blank? && @request.video.attached?
    handle_video_removal_on_update!

    if @request.update(request_params)
      mark_request_as_edited_if_needed!(old_video_key, video_removed_by_user)
      sync_video_thumbnail_after_update!(old_video_key)
      notify_advising_trainer_request_body_updated!
      # /requests/:idにリダイレクトするってこと（つまりrequests#showに移動する）
      redirect_to @request, notice: "更新しました"
    else
      @editing_request = true
      @request_edit_form = @request
      @request_polish_draft_token = request_edit_polish_token(@request)
      @remaining_request_polish_attempts = remaining_polish_attempts(@request_polish_draft_token)
      render :show, status: :unprocessable_entity
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

  def trainers_for_request_form
    User.trainer.order(:name, :id)
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

  def request_edit_polish_token(request)
    "request-edit-#{request.id}-user-#{current_user.id}"
  end

  def advice_edit_polish_token(advice)
    "advice-edit-#{advice.id}-user-#{current_user.id}"
  end

  def advice_polish_attempts_store_for_show
    raw = session[:advice_polish_attempts]
    store = raw.is_a?(Hash) ? raw : {}
    session[:advice_polish_attempts] = store
    store
  end

  def remaining_advice_polish_attempts_for_show(draft_token)
    attempts = advice_polish_attempts_store_for_show[draft_token].to_i
    [AdvicesController::POLISH_MAX_ATTEMPTS - attempts, 0].max
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
        advices: [:user, video_attachment: :blob]
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

  def can_current_user_compose_advice_inline?
    return false unless current_user&.trainer?
    return false if current_user_advice_for_request.present?
    return true if @request.directed_to_trainer_id.blank?

    @request.directed_to_trainer_id == current_user.id
  end

  def can_current_user_edit_advice_inline?
    return false unless current_user&.trainer?
    return false if current_user_advice_for_request.blank?

    true
  end

  def can_current_user_edit_request_inline?
    current_user&.member? && @request.user_id == current_user.id
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
    @request.advices.includes(:user).find_each do |advice|
      Notification.create!(
        user: advice.user,
        request: @request,
        kind: "request_body_updated",
        message: "リクエスト「#{@request.title}」の本文が更新されました"
      )
    end
  end

  def current_user_advice_for_request
    @current_user_advice_for_request ||= @request.advices.find_by(user_id: current_user.id)
  end

  def mark_request_as_edited_if_needed!(old_video_key, video_removed_by_user)
    video_changed = old_video_key != (@request.video.attached? ? @request.video.blob.key : nil)
    return unless @request.saved_change_to_body? || video_removed_by_user || video_changed

    @request.update_column(:edited, true) unless @request.edited?
  end

end
