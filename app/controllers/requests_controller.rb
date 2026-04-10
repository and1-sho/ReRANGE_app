class RequestsController < ApplicationController

  # ログインしていない人はアクセスできない設定
  before_action :authenticate_user!
  # memberかをチェックする設定
  before_action :ensure_member!, only: [:new, :create, :edit, :update, :destroy]
  # リクエストをセットする設定
  before_action :set_request, only: [:show, :edit, :update, :destroy]
  # 閲覧権限: coach は全件、member は自分の相談のみ（show）
  before_action :authorize_request_access!, only: [:show]
  # 相談詳細を開いたら、この相談に紐づく自分宛未読通知を既読にする
  before_action :mark_request_notifications_as_read!, only: [:show]
  # 編集・削除は相談の投稿者本人のみ（member 同士のなりすまし防止）
  before_action :authorize_request_owner!, only: [:edit, :update, :destroy]

  def index
    if current_user.member?
      @requests = current_user.requests
    elsif current_user.coach?
      if params[:filter] == "advised_by_me"
        @requests = Request.joins(:advice).where(advices: { user_id: current_user.id })
      else
        @requests = Request.all
      end
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
      notify_coaches_new_request!
      redirect_to requests_path, notice: "作成しました"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @request.update(request_params)
      notify_advising_coach_request_body_updated!
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

  # 自分とコーチ以外は自分の投稿を表示できない
  def authorize_request_access!
    return if current_user.coach?
    return if @request.user_id == current_user.id
    redirect_to requests_path, alert: "このリクエストを表示する権限がありません"
  end

  # 自分の投稿以外は編集・削除はできない
  def authorize_request_owner!
    return if @request.user_id == current_user.id

    redirect_to requests_path, alert: "このリクエストを編集・削除する権限がありません"
  end

  # この相談に紐づく、ログイン中ユーザー宛の未読通知を既読にする
  def mark_request_notifications_as_read!
    current_user.notifications.unread.where(request_id: @request.id).update_all(read_at: Time.current)
  end

  # 新規相談が投稿されたことを全コーチに通知する
  def notify_coaches_new_request!
    message = "新しい相談「#{@request.title}」が投稿されました"
    User.coach.find_each do |coach|
      Notification.create!(
        user: coach,
        request: @request,
        kind: "new_request",
        message: message
      )
    end
  end

  # 本文が更新されたら、アドバイス済みのコーチにだけ通知する（タイトルだけの変更では送らない）
  def notify_advising_coach_request_body_updated!
    # .saved_change_to_body?はカラムを作った時に自動生成されるメソッド
    return unless @request.saved_change_to_body?
    return if @request.advice.blank?

    Notification.create!(
      user: @request.advice.user,
      request: @request,
      kind: "request_body_updated",
      message: "相談「#{@request.title}」の本文が更新されました"
    )
  end

end
