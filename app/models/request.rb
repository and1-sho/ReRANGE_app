# ============================================================
# Request モデル
#
# メンバーが投稿する「リクエスト（質問・相談）」を表すモデル。
# タイトル・本文・動画を持ち、トレーナーからアドバイスを受ける。
# ============================================================
class Request < ApplicationRecord
  include ValidatesAttachedVideo

  # タイトルは必須・最大24文字
  validates :title, presence: true, length: { maximum: 24 }
  # 本文は必須・最大300文字
  validates :body,  presence: true, length: { maximum: 300 }

  # 動画は1本だけ添付できる（Active Storage で管理）
  has_one_attached :video
  # 一覧画面表示用のサムネイル画像（VideoThumbnailJob が非同期で生成する）
  has_one_attached :video_thumbnail

  # リクエストはどのメンバーが投稿したかを持つ
  belongs_to :user

  # リクエストには複数のアドバイスが付く。リクエストを削除するとアドバイスも消える
  has_many :advices,              dependent: :destroy
  # リクエストには有料アドバイス取引が紐づく。リクエスト削除で取引も消える
  has_many :paid_advice_requests, dependent: :destroy
  # リクエストには通知が紐づく。リクエスト削除で通知も消える
  has_many :notifications,        dependent: :destroy

  # このリクエストに付いているアドバイスの件数を返す
  # アドバイスはすでにメモリに読み込まれている場合は DB に問い合わせない
  def advice_count
    advices.size
  end
end
