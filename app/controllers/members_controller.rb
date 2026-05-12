# ============================================================
# MembersController
#
# メンバー（ユーザー）のプロフィール表示・編集を担うコントローラ。
# MVP ver.0.1.0 ではプロフィール機能を停止しており、
# アクセスされた場合はリクエスト一覧にリダイレクトする。
# ============================================================
class MembersController < ApplicationController
  before_action :authenticate_user!
  # MVP ver.0.1.0: プロフィール機能は未使用。
  before_action -> { redirect_to requests_path }

  def show;   end
  def edit;   end
  def update; end
end
