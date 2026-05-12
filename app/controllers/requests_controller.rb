# ============================================================
# RequestsController
#
# メンバーが投稿する「リクエスト（質問・相談）」に関する操作を担うコントローラ。
# 一覧表示・詳細表示・新規作成を提供する。
# 編集・削除は MVP ver.0.1.0 では使用しないためリダイレクトで封じている。
# ============================================================
class RequestsController < ApplicationController
  # AI 文章整えの最大試行回数
  POLISH_MAX_ATTEMPTS = 2

  # ログインしていないユーザーはすべてのアクションに入れない
  before_action :authenticate_user!
  # 新規作成・AI整えはメンバーだけが実行できる
  before_action :ensure_member!, only: [:new, :create, :polish]
  # show / edit / update / destroy では URL の :id からリクエストを DB から取り出す
  before_action :set_request,    only: [:show, :edit, :update, :destroy]
  # 詳細を開いたとき、そのリクエストに紐づく自分宛の未読通知を既読にする
  before_action :mark_request_notifications_as_read!, only: [:show]
  # 新規投稿フォーム・投稿時に AI整えのセッション情報を初期化する
  before_action :prepare_request_polish_session!,     only: [:new, :create]

  # GET /requests
  # リクエスト一覧を表示する
  # トレーナーは「自分がアドバイス済みのリクエストだけ」に絞り込めるフィルター付き
  def index
    @requests = if current_user.trainer? && params[:filter] == "advised_by_me"
                  # フィルターあり：自分のアドバイスが付いているリクエストだけを取得
                  Request.joins(:advices).where(advices: { user_id: current_user.id }).distinct
                else
                  # フィルターなし：全リクエストを取得
                  Request.all
                end

    # N+1 クエリを防ぐため、関連データをまとめて取得する
    @requests = @requests
                  .includes(:user, :advices, video_attachment: :blob, video_thumbnail_attachment: :blob)
                  .order(created_at: :desc)
  end

  # GET /requests/:id
  # リクエスト詳細を表示する
  # トレーナーだった場合、まだアドバイスを書いていなければインラインの投稿フォームを準備する
  def show
    if can_compose_advice_inline?
      @inline_advice = Advice.new
      # AI整えのセッションキー（画面をリロードしても試行回数を引き継ぐため固定キーを使う）
      @inline_advice_polish_draft_token = params[:advice_polish_draft_token].presence ||
                                          "advice-new-request-#{@request.id}-user-#{current_user.id}"
      @remaining_inline_advice_polish_attempts =
        remaining_advice_polish_attempts_for_show(@inline_advice_polish_draft_token)
    end
  end

  # GET /requests/new
  # 新規リクエスト投稿フォームを表示する
  def new
    @request = Request.new
  end

  # POST /requests
  # フォームの内容を受け取ってリクエストを保存する
  def create
    @request = current_user.requests.build(request_params)
    # MVP ver.0.1.0: 公開/非公開 UI は未使用。全リクエストを公開扱いに固定
    @request.directed_to_trainer_id = nil
    draft_token = params[:request_polish_draft_token].to_s

    if @request.save
      clear_polish_attempts!(draft_token)               # AI整えの試行カウントをリセット
      enqueue_video_thumbnail_job_if_attached!(@request) # 動画があればサムネ生成ジョブを非同期で実行
      notify_trainers_new_request!                       # 全トレーナーに通知を作成
      redirect_to requests_path, notice: "作成しました"
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /requests/:id/edit
  # MVP ver.0.1.0 では編集機能を停止している
  def edit
    redirect_to request_path(@request), alert: "現在この機能は利用できません"
  end

  # PATCH /requests/:id
  # MVP ver.0.1.0 では更新機能を停止している
  def update
    redirect_to request_path(@request), alert: "現在この機能は利用できません"
  end

  # DELETE /requests/:id
  # MVP ver.0.1.0 では削除機能を停止している
  def destroy
    redirect_to request_path(@request), alert: "現在この機能は利用できません"
  end

  # POST /requests/polish
  # AI に本文の文章整えを依頼して、提案テキストを JSON で返す（非同期・Ajax）
  def polish
    draft_token = params[:draft_token].to_s
    if draft_token.blank?
      return render json: { error: "整形セッションが無効です。再読み込みしてください。" }, status: :unprocessable_entity
    end

    if remaining_polish_attempts(draft_token) <= 0
      return render json: { error: "文章を整える操作は2回までです", remaining_attempts: 0 }, status: :unprocessable_entity
    end

    body = params[:body].to_s.strip
    if body.blank?
      return render json: { error: "本文を入力してください", remaining_attempts: remaining_polish_attempts(draft_token) }, status: :unprocessable_entity
    end

    polisher = ::RequestTextPolisher.new(body: body)
    proposal = polisher.call
    increment_polish_attempts!(draft_token) # 試行回数を1増やす
    render json: proposal.merge(remaining_attempts: remaining_polish_attempts(draft_token)), status: :ok
  rescue RequestTextPolisher::PolishError => e
    render json: { error: e.message, remaining_attempts: remaining_polish_attempts(draft_token) }, status: :unprocessable_entity
  end

  private

  # URL の :id からリクエストを取得し @request に入れる
  # N+1 を防ぐためアドバイスと投稿者・動画も一緒に読み込む
  def set_request
    @request = Request.includes(
      :user,
      video_attachment: :blob,
      advices: [:user, video_attachment: :blob]
    ).find(params[:id])
  end

  # フォームから受け取っていいパラメータだけを許可する（セキュリティ対策）
  def request_params
    params.require(:request).permit(:title, :body, :video)
  end

  # AI整えで使うセッションキーと残り試行回数を初期化する
  def prepare_request_polish_session!
    @request_polish_draft_token = params[:request_polish_draft_token].presence || SecureRandom.uuid
    @remaining_polish_attempts  = remaining_polish_attempts(@request_polish_draft_token)
  end

  # セッションに保存している「AI整え試行回数」のストアを取得する
  # セッションの値が壊れていた場合でも空ハッシュに補正する
  def polish_attempts_store
    store = session[:request_polish_attempts]
    store = {} unless store.is_a?(Hash)
    session[:request_polish_attempts] = store
  end

  # 指定トークンの試行回数を返す（未記録なら0）
  def polish_attempts(draft_token)
    polish_attempts_store[draft_token].to_i
  end

  # 指定トークンの残り試行回数を返す（0 未満にはならない）
  def remaining_polish_attempts(draft_token)
    [POLISH_MAX_ATTEMPTS - polish_attempts(draft_token), 0].max
  end

  # 試行回数を1増やして保存する
  def increment_polish_attempts!(draft_token)
    polish_attempts_store[draft_token] = polish_attempts(draft_token) + 1
  end

  # 投稿完了時に試行回数をリセットする（次の投稿で試行回数が残るのを防ぐ）
  def clear_polish_attempts!(draft_token)
    return if draft_token.blank?

    polish_attempts_store.delete(draft_token)
  end

  # アドバイス投稿フォーム用の AI整え試行回数ストアを取得する
  # リクエストのポリッシュストアとは別のセッションキーで管理する
  def advice_polish_attempts_store_for_show
    store = session[:advice_polish_attempts]
    store = {} unless store.is_a?(Hash)
    session[:advice_polish_attempts] = store
  end

  # アドバイス投稿フォームの残り AI整え試行回数を返す
  def remaining_advice_polish_attempts_for_show(draft_token)
    attempts = advice_polish_attempts_store_for_show[draft_token].to_i
    [AdvicesController::POLISH_MAX_ATTEMPTS - attempts, 0].max
  end

  # 現在のユーザーがこのリクエストにインラインでアドバイスを投稿できるか
  # 条件：トレーナーであること、かつまだアドバイスを書いていないこと
  def can_compose_advice_inline?
    current_user&.trainer? &&
      @request.advices.none? { |a| a.user_id == current_user.id }
  end

  # このリクエストに紐づく、ログイン中ユーザー宛の未読通知をすべて既読にする
  def mark_request_notifications_as_read!
    current_user.notifications.unread.where(request_id: @request.id).update_all(read_at: Time.current)
  end

  # 新しいリクエストが投稿されたことを全トレーナーに通知する
  def notify_trainers_new_request!
    message = "新しいリクエスト「#{@request.title}」が投稿されました"
    User.trainer.find_each do |trainer|
      Notification.create!(
        user: trainer, request: @request,
        kind: "new_request", message: message
      )
    end
  end

  # 動画が添付されていれば、サムネイル生成ジョブをキューに入れる
  def enqueue_video_thumbnail_job_if_attached!(request)
    VideoThumbnailJob.perform_later("Request", request.id) if request.video.attached?
  end

  # メンバー以外がリクエスト関連のアクションを実行しようとした場合に弾く
  # JSON リクエストの場合は 403 エラーを返す（Stimulus から呼ばれる polish アクション用）
  def ensure_member!
    return if current_user.member?

    message = "メンバーのみリクエストを作成できます"
    if request.format.json?
      render json: { error: message }, status: :forbidden
    else
      redirect_to requests_path, alert: message
    end
  end
end
