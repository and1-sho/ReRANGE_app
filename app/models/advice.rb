class Advice < ApplicationRecord
  include ValidatesAttachedVideo

  # adviceのボディーを必須項目にする
  validates :body, presence: true

  # トレーナーからの動画は1アドバイスにつき1本（MP4 / MOV・100MBまで・詳細で再生）
  has_one_attached :video
  has_one_attached :video_thumbnail

  # adviceはrequestに属する
  belongs_to :request

  # adviceはトレーナー（User）に属する
  belongs_to :user

  validates :user_id, uniqueness: { scope: :request_id }
end
