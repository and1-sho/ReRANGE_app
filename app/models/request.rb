class Request < ApplicationRecord
  include ValidatesAttachedVideo

  # requestのタイトルを必須項目にする（UI 上のカウンタと揃えて最大24字）
  validates :title, presence: true, length: { maximum: 24 }
  # requestのボディーを必須項目にする（UI のカウンタと揃えて最大300字）
  validates :body, presence: true, length: { maximum: 300 }

  # 動画は1リクエストにつき1本（MP4 / MOV・100MBまで）
  has_one_attached :video
  # 一覧用サムネ（VideoThumbnailJob）
  has_one_attached :video_thumbnail

  # requestはユーザーに属する
  belongs_to :user
  # 指定トレーナー宛（一覧には出さない）。未設定ならログイン全員向けの公開リクエスト
  belongs_to :directed_to_trainer, class_name: "User", optional: true
  # requestは複数のadviceを持つ（リクエスト削除時はアドバイスも消す）
  has_many :advices, dependent: :destroy
  # このリクエストに紐づく通知（リクエスト削除時は通知も消す）
  has_many :notifications, dependent: :destroy

  before_validation :normalize_directed_to_trainer_id
  validate :directed_to_trainer_must_be_trainer

  # 一覧（みんなのリクエスト）に載せるもの
  scope :on_public_feed, -> { where(directed_to_trainer_id: nil) }

  # ログイン中ユーザーが詳細を閲覧できるか
  def visible_to?(viewer)
    return false if viewer.blank?

    return true if user_id == viewer.id
    return true if directed_to_trainer_id.nil?
    return true if viewer.trainer? && directed_to_trainer_id == viewer.id

    false
  end

  def public_feed?
    directed_to_trainer_id.blank?
  end

  def advice_count
    advices.size
  end

  private

  def normalize_directed_to_trainer_id
    self.directed_to_trainer_id = nil if directed_to_trainer_id.blank?
  end

  def directed_to_trainer_must_be_trainer
    return if directed_to_trainer_id.blank?

    trainer = User.find_by(id: directed_to_trainer_id)
    errors.add(:directed_to_trainer_id, "はトレーナーを指定してください") unless trainer&.trainer?
  end
end
