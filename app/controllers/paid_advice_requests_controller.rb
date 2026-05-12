# ============================================================
# PaidAdviceRequestsController
#
# 有料アドバイスの購入フロー（Stripe 決済）を担うコントローラ。
# メンバーがトレーナーの有料メニューを選択して決済ページへ進み、
# 決済後に Stripe から success / cancel のコールバックを受け取る。
# MVP ver.0.1.0 では有料機能を停止しており、
# アクセスされた場合はリクエスト一覧にリダイレクトする。
# ============================================================
class PaidAdviceRequestsController < ApplicationController
  before_action :authenticate_user!
  # MVP ver.0.1.0: 有料アドバイス機能は未使用。
  before_action -> { redirect_to requests_path }

  def create;  end # 購入開始・Stripe セッションを作成してリダイレクト
  def success; end # Stripe 決済成功後のコールバック
  def cancel;  end # Stripe 決済キャンセル後のコールバック
end
