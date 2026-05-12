# ============================================================
# Advice モデル
#
# トレーナーがリクエストに対して投稿する「アドバイス」を表すモデル。
# テキスト・動画を持つ。1リクエストにつき1トレーナー1件のみ投稿できる。
# ============================================================
class Advice < ApplicationRecord
  include ValidatesAttachedVideo

  # 本文は必須
  validates :body, presence: true
  # 同じリクエストに同じトレーナーが2件投稿できないようにする
  validates :user_id, uniqueness: { scope: :request_id }

  # 動画は1本だけ添付できる
  has_one_attached :video
  # 一覧用サムネイル（VideoThumbnailJob が非同期で生成する）
  has_one_attached :video_thumbnail

  # アドバイスはどのリクエストへのものかを持つ
  belongs_to :request
  # アドバイスはどのトレーナーが書いたかを持つ
  belongs_to :user

  # このアドバイスに紐づく有料取引。アドバイス削除で取引も消える
  has_many :paid_advice_requests, dependent: :destroy
end
