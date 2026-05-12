# ============================================================
# TrainersController
#
# トレーナーの一覧・プロフィール表示・編集を担うコントローラ。
# MVP ver.0.1.0 ではこれらの機能を停止しており、
# アクセスされた場合はリクエスト一覧にリダイレクトする。
# ============================================================
class TrainersController < ApplicationController
  before_action :authenticate_user!
  # MVP ver.0.1.0: トレーナー一覧・プロフィール機能は未使用。
  before_action -> { redirect_to requests_path }

  def index;  end
  def show;   end
  def edit;   end
  def update; end
end
