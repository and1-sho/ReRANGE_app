class NotificationsController < ApplicationController

  before_action :authenticate_user!
  # MVP ver.0.1.0: 通知機能は未使用。URL直打ちを含めアクセス不可にする。
  before_action -> { redirect_to requests_path }

  def index
    @notifications = current_user.notifications.includes(:request).order(created_at: :desc)
  end
end
