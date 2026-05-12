# ============================================================
# NotificationsController
#
# ユーザーへの通知一覧を担うコントローラ。
# MVP ver.0.1.0 では通知一覧ページを停止しており、
# アクセスされた場合はリクエスト一覧にリダイレクトする。
# 通知レコードの作成自体は継続しているため、将来的に復活可能。
# ============================================================
class NotificationsController < ApplicationController
  before_action :authenticate_user!
  # MVP ver.0.1.0: 通知機能は未使用。
  before_action -> { redirect_to requests_path }

  def index; end
end
