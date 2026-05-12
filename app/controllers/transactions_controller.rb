# ============================================================
# TransactionsController
#
# 有料アドバイスの取引（PaidAdviceRequest）に関する操作を担うコントローラ。
# 取引一覧・詳細・トレーナーによる納品・メンバーによる完了確認を提供する。
# MVP ver.0.1.0 では取引機能を停止しており、
# アクセスされた場合はリクエスト一覧にリダイレクトする。
# ============================================================
class TransactionsController < ApplicationController
  before_action :authenticate_user!
  # MVP ver.0.1.0: 取引機能は未使用。
  before_action -> { redirect_to requests_path }

  def index;    end
  def show;     end
  def deliver;  end
  def complete; end
end
