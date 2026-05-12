# ============================================================
# Notification モデル
#
# アプリ内の通知を表すモデル。
# 「アドバイスが届いた」「新しいリクエストが投稿された」などのイベントを
# DB に保存し、ユーザーに通知する。
# MVP ver.0.1.0 では通知一覧ページは非表示だが、通知レコードの作成は継続している。
# ============================================================
class Notification < ApplicationRecord
  # 通知を受け取るユーザー
  belongs_to :user
  # どのリクエストに関する通知かを持つ
  belongs_to :request

  # kind（種別）と message（本文）は必須
  validates :kind,    presence: true
  validates :message, presence: true

  # read_at（既読日時）が nil のものだけを取得するスコープ
  # 使い方: current_user.notifications.unread
  scope :unread, -> { where(read_at: nil) }
end
