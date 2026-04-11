class Request < ApplicationRecord
  include ValidatesAttachedVideo

  # requestのタイトルを必須項目にする
  validates :title, presence: true
  # requestのボディーを必須項目にする
  validates :body, presence: true

  # 動画は1リクエストにつき1本（MP4 / MOV・100MBまで）
  has_one_attached :video
  # 一覧用サムネ（VideoThumbnailJob）
  has_one_attached :video_thumbnail

  # requestはユーザーに属する
  belongs_to :user
  # requestは一つのadviceを持つ（相談削除時はアドバイスも消す）
  has_one :advice, dependent: :destroy
  # この相談に紐づく通知（相談削除時は通知も消す）
  has_many :notifications, dependent: :destroy
end
