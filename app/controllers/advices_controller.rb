# ============================================================
# AdvicesController
#
# トレーナーがリクエストに投稿する「アドバイス」に関する操作を担うコントローラ。
# アドバイスの投稿・AI文章整えを提供する。
# 編集・削除は MVP ver.0.1.0 では使用しないためリダイレクトで封じている。
# ============================================================
class AdvicesController < ApplicationController
  # AI 文章整えの最大試行回数
  POLISH_MAX_ATTEMPTS = 2

  # ログインしていないユーザーはすべてのアクションに入れない
  before_action :authenticate_user!
  # URL の :request_id からリクエストを取得して @request に入れる
  before_action :set_request
  # 投稿・編集・削除・AI整えはトレーナーのみ実行できる
  before_action :ensure_trainer!, only: [:new, :create, :edit, :update, :destroy, :polish]
  # AI整えアクションの権限チェック（トレーナーかどうか）
  before_action :authorize_advice_polish!, only: [:polish]
  # 同じリクエストに同じトレーナーが2件投稿しないようにする
  before_action :ensure_not_already_advised!, only: [:new, :create]

  # GET /requests/:request_id/advices/new
  # アドバイス投稿フォームを表示する（インライン投稿とは別の専用ページ）
  def new
    @advice = Advice.new
    @advice_polish_draft_token = SecureRandom.uuid
    @remaining_polish_attempts = remaining_advice_polish_attempts(@advice_polish_draft_token)
  end

  # POST /requests/:request_id/advices
  # フォームの内容を受け取ってアドバイスを保存する
  def create
    @advice = @request.advices.build(advice_params)
    @advice.user = current_user
    draft_token = params[:advice_polish_draft_token].to_s

    if @advice.save
      clear_advice_polish_attempts!(draft_token)             # AI整えの試行カウントをリセット
      enqueue_video_thumbnail_job_if_attached!(@advice)      # 動画があればサムネ生成ジョブを非同期で実行
      notify_request_owner_advice_received!                  # リクエスト投稿者に「アドバイスが届いた」通知を作成
      redirect_to request_path(@request), notice: "アドバイスを投稿しました"
    else
      # バリデーションエラー時：詳細ページをそのまま再描画してエラーを表示する
      @inline_advice = @advice
      render "requests/show", status: :unprocessable_entity
    end
  end

  # GET /requests/:request_id/advices/:id/edit
  # MVP ver.0.1.0 では編集機能を停止している
  def edit
    redirect_to request_path(@request), alert: "現在この機能は利用できません"
  end

  # PATCH /requests/:request_id/advices/:id
  # MVP ver.0.1.0 では更新機能を停止している
  def update
    redirect_to request_path(@request), alert: "現在この機能は利用できません"
  end

  # DELETE /requests/:request_id/advices/:id
  # MVP ver.0.1.0 では削除機能を停止している
  def destroy
    redirect_to request_path(@request), alert: "現在この機能は利用できません"
  end

  # POST /requests/:request_id/advices/polish
  # AI に本文の文章整えを依頼して、提案テキストを JSON で返す（非同期・Ajax）
  def polish
    draft_token = params[:draft_token].to_s
    if draft_token.blank?
      return render json: { error: "整形セッションが無効です。再読み込みしてください。" }, status: :unprocessable_entity
    end

    if remaining_advice_polish_attempts(draft_token) <= 0
      return render json: { error: "文章を整える操作は2回までです", remaining_attempts: 0 }, status: :unprocessable_entity
    end

    body = params[:body].to_s.strip
    if body.blank?
      return render json: { error: "本文を入力してください", remaining_attempts: remaining_advice_polish_attempts(draft_token) }, status: :unprocessable_entity
    end

    polisher = ::AdviceTextPolisher.new(body: body)
    proposal = polisher.call
    increment_advice_polish_attempts!(draft_token) # 試行回数を1増やす
    render json: proposal.merge(remaining_attempts: remaining_advice_polish_attempts(draft_token)), status: :ok
  rescue AdviceTextPolisher::PolishError => e
    render json: { error: e.message, remaining_attempts: remaining_advice_polish_attempts(draft_token) }, status: :unprocessable_entity
  end

  private

  # URL の :request_id からリクエストを取得し @request に入れる
  # N+1 を防ぐためアドバイスと動画も一緒に読み込む
  def set_request
    @request = Request.includes(
      :user,
      { advices: [:user, { video_attachment: :blob }] },
      video_attachment: :blob,
      video_thumbnail_attachment: :blob
    ).find(params[:request_id])
  end

  # フォームから受け取っていいパラメータだけを許可する（セキュリティ対策）
  def advice_params
    params.require(:advice).permit(:body, :video)
  end

  # すでに同じリクエストにアドバイスを投稿済みなら弾く
  def ensure_not_already_advised!
    return if @request.advices.where(user_id: current_user.id).blank?

    redirect_to request_path(@request), alert: "このリクエストにはすでにアドバイスを投稿しています"
  end

  # AI整えはトレーナーのみ実行できる（JSON レスポンスで 403 を返す）
  def authorize_advice_polish!
    return if current_user.trainer?

    render json: { error: "トレーナーのみアドバイスできます" }, status: :forbidden
  end

  # アドバイスを受け取ったことをリクエストの投稿者（メンバー）に通知する
  def notify_request_owner_advice_received!
    Notification.create!(
      user: @request.user, request: @request,
      kind: "advice_received",
      message: "「#{@request.title}」にアドバイスが届きました"
    )
  end

  # 動画が添付されていれば、サムネイル生成ジョブをキューに入れる
  def enqueue_video_thumbnail_job_if_attached!(advice)
    VideoThumbnailJob.perform_later("Advice", advice.id) if advice.video.attached?
  end

  # セッションに保存している「AI整え試行回数」のストアを取得する
  def advice_polish_attempts_store
    store = session[:advice_polish_attempts]
    store = {} unless store.is_a?(Hash)
    session[:advice_polish_attempts] = store
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

  # 投稿完了時に試行回数をリセットする
  def clear_advice_polish_attempts!(draft_token)
    return if draft_token.blank?

    advice_polish_attempts_store.delete(draft_token)
  end

  # トレーナー以外がアドバイス関連のアクションを実行しようとした場合に弾く
  # JSON リクエストの場合は 403 エラーを返す（polish アクション用）
  def ensure_trainer!
    return if current_user.trainer?

    message = "トレーナーのみアドバイスできます"
    if request.format.json?
      render json: { error: message }, status: :forbidden
    else
      redirect_to requests_path, alert: message
    end
  end
end
