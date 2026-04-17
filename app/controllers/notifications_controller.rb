class NotificationsController < ApplicationController

  # ログインしていない人はアクセスできない設定
  before_action :authenticate_user!

  def index
    # 自分宛の通知を新しい順に並べる（リクエストタイトルなどは view で使うので request を先読み）
    @notifications = current_user.notifications.includes(:request).order(created_at: :desc)
  end
end
